#!/usr/bin/env python3

issues = {} # Returned issues dict
buildHooks = {} # Options, and others hooks
haltOnErrors = True

# Main wrapper function. Required to make local vars work correctly
def main():
  import os
  import time
  import ruamel.yaml
  import signal
  import sys
  import subprocess

  from blessed import Terminal
  from deps.chars import specialChars, commonTopBorder, commonBottomBorder, commonEmptyLine, padText
  from deps.consts import servicesDirectory, templatesDirectory, volumesDirectory, buildSettingsFileName, buildCache, servicesFileName
  from deps.common_functions import getExternalPorts, getInternalPorts, checkPortConflicts, enterPortNumberWithWhiptail, generateRandomString

  yaml = ruamel.yaml.YAML()
  yaml.preserve_quotes = True

  global dockerComposeServicesYaml # The loaded memory YAML of all checked services
  global toRun # Switch for which function to run when executed
  global buildHooks # Where to place the options menu result
  global currentServiceName # Name of the current service
  global issues # Returned issues dict
  global haltOnErrors # Turn on to allow erroring
  global hideHelpText # Showing and hiding the help controls text
  global serviceService

  serviceVolume = volumesDirectory + currentServiceName
  serviceService = servicesDirectory + currentServiceName
  serviceTemplate = templatesDirectory + currentServiceName
  buildSettings = serviceService + buildSettingsFileName

  try: # If not already set, then set it.
    hideHelpText = hideHelpText
  except:
    hideHelpText = False

  documentationHint = 'https://sensorsiot.github.io/IOTstack/Containers/NextCloud'

  # runtime vars
  portConflicts = []

  # This lets the menu know whether to put " >> Options " or not
  # This function is REQUIRED.
  def checkForOptionsHook():
    try:
      buildHooks["options"] = callable(runOptionsMenu)
    except:
      buildHooks["options"] = False
      return buildHooks
    return buildHooks

  # This function is REQUIRED.
  def checkForPreBuildHook():
    try:
      buildHooks["preBuildHook"] = callable(preBuild)
    except:
      buildHooks["preBuildHook"] = False
      return buildHooks
    return buildHooks

  # This function is REQUIRED.
  def checkForPostBuildHook():
    try:
      buildHooks["postBuildHook"] = callable(postBuild)
    except:
      buildHooks["postBuildHook"] = False
      return buildHooks
    return buildHooks

  # This function is REQUIRED.
  def checkForRunChecksHook():
    try:
      buildHooks["runChecksHook"] = callable(runChecks)
    except:
      buildHooks["runChecksHook"] = False
      return buildHooks
    return buildHooks

  # This service will not check anything unless this is set
  # This function is optional, and will run each time the menu is rendered
  def runChecks():
    checkForIssues()
    return []

  # This function is optional, and will run after the docker-compose.yml file is written to disk.
  def postBuild():
    commandToRun = "chmod -R 0770 %s" % serviceVolume + '/html'
    print('[Nextcloud::postBuild]: %s' % commandToRun)
    subprocess.call(commandToRun, shell=True)
    return True

  # This function is optional, and will run just before the build docker-compose.yml code.
  def preBuild():
    global dockerComposeServicesYaml
    # Setup service directory
    if not os.path.exists(serviceService):
      os.makedirs(serviceService, exist_ok=True)

    os.makedirs(serviceVolume, exist_ok=True)
    os.makedirs(serviceVolume + '/html', exist_ok=True)

    # Multi-service:
    with open((r'%s/' % serviceTemplate) + servicesFileName) as objServiceFile:
      servicesListed = yaml.load(objServiceFile)

    oldBuildCache = {}
    try:
      with open(r'%s' % buildCache) as objBuildCache:
        oldBuildCache = yaml.load(objBuildCache)
    except:
      pass

    buildCacheServices = {}
    if "services" in oldBuildCache:
      buildCacheServices = oldBuildCache["services"]

    if not os.path.exists(serviceService):
      os.makedirs(serviceService, exist_ok=True)

    if os.path.exists(buildSettings):

      # Password randomisation
      with open(r'%s' % buildSettings) as objBuildSettingsFile:
        nextCloudYamlBuildOptions = yaml.load(objBuildSettingsFile)
        if (
          nextCloudYamlBuildOptions["databasePasswordOption"] == "Randomise passwords for this build"
          or nextCloudYamlBuildOptions["databasePasswordOption"] == "Randomise passwords every build"
          or nextCloudYamlBuildOptions["databasePasswordOption"] == "Use default passwords for this build"
        ):
          if nextCloudYamlBuildOptions["databasePasswordOption"] == "Use default passwords for this build":
            mySqlRootPassword = "IOtSt4ckToorMySqlDb"
            mySqlPassword = "IOtSt4ckmySqlDbPw"
          else:
            mySqlPassword = generateRandomString()
            mySqlRootPassword = generateRandomString()

          for (index, serviceName) in enumerate(servicesListed):
            dockerComposeServicesYaml[serviceName] = servicesListed[serviceName]
            if "environment" in servicesListed[serviceName]:
              for (envIndex, envName) in enumerate(servicesListed[serviceName]["environment"]):
                envName = envName.replace("%randomMySqlPassword%", mySqlPassword)
                dockerComposeServicesYaml[serviceName]["environment"][envIndex] = envName.replace("%randomPassword%", mySqlRootPassword)

          # Ensure you update the "Do nothing" and other 2 strings used for password settings in 'passwords.py'
          if (nextCloudYamlBuildOptions["databasePasswordOption"] == "Randomise passwords for this build"):
            nextCloudYamlBuildOptions["databasePasswordOption"] = "Do nothing"
            with open(buildSettings, 'w') as outputFile:
              yaml.dump(nextCloudYamlBuildOptions, outputFile)
        else: # Do nothing - don't change password
          for (index, serviceName) in enumerate(buildCacheServices):
            if serviceName in buildCacheServices: # Load service from cache if exists (to maintain password)
              dockerComposeServicesYaml[serviceName] = buildCacheServices[serviceName]
            else:
              dockerComposeServicesYaml[serviceName] = servicesListed[serviceName]

    else:
      print("NextCloud Warning: Build settings file not found, using default password")
      time.sleep(1)
      mySqlRootPassword = "IOtSt4ckToorMySqlDb"
      mySqlPassword = "IOtSt4ckmySqlDbPw"
      for (index, serviceName) in enumerate(servicesListed):
        dockerComposeServicesYaml[serviceName] = servicesListed[serviceName]
        if "environment" in servicesListed[serviceName]:
          for (envIndex, envName) in enumerate(servicesListed[serviceName]["environment"]):
            envName = envName.replace("%randomMySqlPassword%", mySqlPassword)
            dockerComposeServicesYaml[serviceName]["environment"][envIndex] = envName.replace("%randomPassword%", mySqlRootPassword)
        nextCloudYamlBuildOptions = {
          "version": "1",
          "application": "IOTstack",
          "service": "NextCloud",
          "comment": "NextCloud Build Options"
        }

      nextCloudYamlBuildOptions["databasePasswordOption"] = "Do nothing"
      with open(buildSettings, 'w') as outputFile:
        yaml.dump(nextCloudYamlBuildOptions, outputFile)

    return True

  # #####################################
  # Supporting functions below
  # #####################################

  def checkForIssues():
    for (index, serviceName) in enumerate(dockerComposeServicesYaml):
      if not currentServiceName == serviceName: # Skip self
        currentServicePorts = getExternalPorts(currentServiceName, dockerComposeServicesYaml)
        portConflicts = checkPortConflicts(serviceName, currentServicePorts, dockerComposeServicesYaml)
        if (len(portConflicts) > 0):
          issues["portConflicts"] = portConflicts

  # #####################################
  # End Supporting functions
  # #####################################

  ############################
  # Menu Logic
  ############################

  global currentMenuItemIndex
  global selectionInProgress
  global menuNavigateDirection
  global needsRender

  selectionInProgress = True
  currentMenuItemIndex = 0
  menuNavigateDirection = 0
  needsRender = 1
  term = Terminal()
  hotzoneLocation = [((term.height // 16) + 6), 0]

  def goBack():
    global selectionInProgress
    global needsRender
    selectionInProgress = False
    needsRender = 1
    return True

  def enterPortNumberExec():
    # global term
    global needsRender
    global dockerComposeServicesYaml
    externalPort = getExternalPorts(currentServiceName, dockerComposeServicesYaml)[0]
    internalPort = getInternalPorts(currentServiceName, dockerComposeServicesYaml)[0]
    newPortNumber = enterPortNumberWithWhiptail(term, dockerComposeServicesYaml, currentServiceName, hotzoneLocation, externalPort)

    if newPortNumber > 0:
      dockerComposeServicesYaml[currentServiceName]["ports"][0] = "{newExtPort}:{oldIntPort}".format(
        newExtPort = newPortNumber,
        oldIntPort = internalPort
      )
      createMenu()
    needsRender = 1

  def setPasswordOptions():
    global needsRender
    global hasRebuiltAddons
    passwordOptionsMenuFilePath = "./.templates/{currentService}/passwords.py".format(currentService=currentServiceName)
    with open(passwordOptionsMenuFilePath, "rb") as pythonDynamicImportFile:
      code = compile(pythonDynamicImportFile.read(), passwordOptionsMenuFilePath, "exec")
    execGlobals = {
      "currentServiceName": currentServiceName,
      "renderMode": renderMode
    }
    execLocals = {}
    screenActive = False
    exec(code, execGlobals, execLocals)
    signal.signal(signal.SIGWINCH, onResize)
    screenActive = True
    needsRender = 1

  def onResize(sig, action):
    global nextCloudBuildOptions
    global currentMenuItemIndex
    mainRender(1, nextCloudBuildOptions, currentMenuItemIndex)

  nextCloudBuildOptions = []

  def createMenu():
    global nextCloudBuildOptions
    try:
      nextCloudBuildOptions = []
      portNumber = getExternalPorts(currentServiceName, dockerComposeServicesYaml)[0]
      nextCloudBuildOptions.append([
        "Change external WUI Port Number from: {port}".format(port=portNumber),
        enterPortNumberExec
      ])
    except: # Error getting port
      pass
    nextCloudBuildOptions.append([
      "Database Password Options",
      setPasswordOptions
    ])
    nextCloudBuildOptions.append(["Go back", goBack])

  def runOptionsMenu():
    createMenu()
    menuEntryPoint()
    return True

  def renderHotZone(term, menu, selection, hotzoneLocation):
    lineLengthAtTextStart = 71
    print(term.move(hotzoneLocation[0], hotzoneLocation[1]))
    for (index, menuItem) in enumerate(menu):
      toPrint = ""
      if index == selection:
        toPrint += ('{bv} -> {t.blue_on_green} {title} {t.normal} <-'.format(t=term, title=menuItem[0], bv=specialChars[renderMode]["borderVertical"]))
      else:
        toPrint += ('{bv}    {t.normal} {title}    '.format(t=term, title=menuItem[0], bv=specialChars[renderMode]["borderVertical"]))

      for i in range(lineLengthAtTextStart - len(menuItem[0])):
        toPrint += " "

      toPrint += "{bv}".format(bv=specialChars[renderMode]["borderVertical"])

      toPrint = term.center(toPrint)

      print(toPrint)

  def mainRender(needsRender, menu, selection):
    term = Terminal()
    
    if needsRender == 1:
      print(term.clear())
      print(term.move_y(term.height // 16))
      print(term.black_on_cornsilk4(term.center('IOTstack Next Cloud Options')))
      print("")
      print(term.center(commonTopBorder(renderMode)))
      print(term.center(commonEmptyLine(renderMode)))
      print(term.center("{bv}      Select Option to configure                                                {bv}".format(bv=specialChars[renderMode]["borderVertical"])))
      print(term.center(commonEmptyLine(renderMode)))

    if needsRender >= 1:
      renderHotZone(term, menu, selection, hotzoneLocation)

    if needsRender == 1:
      print(term.center(commonEmptyLine(renderMode)))
      print(term.center(commonEmptyLine(renderMode)))
      if not hideHelpText:
        print(term.center(commonEmptyLine(renderMode)))
        print(term.center("{bv}      Controls:                                                                 {bv}".format(bv=specialChars[renderMode]["borderVertical"])))
        print(term.center("{bv}      [Up] and [Down] to move selection cursor                                  {bv}".format(bv=specialChars[renderMode]["borderVertical"])))
        print(term.center("{bv}      [H] Show/hide this text                                                   {bv}".format(bv=specialChars[renderMode]["borderVertical"])))
        print(term.center("{bv}      [Enter] to run command or save input                                      {bv}".format(bv=specialChars[renderMode]["borderVertical"])))
        print(term.center("{bv}      [Escape] to go back to build stack menu                                   {bv}".format(bv=specialChars[renderMode]["borderVertical"])))
        print(term.center(commonEmptyLine(renderMode)))
        if len(documentationHint) > 1:
          if len(documentationHint) > 56:
            documentationAndPadding = padText(documentationHint, 71)
            print(term.center("{bv}      Documentation:                                                            {bv}".format(bv=specialChars[renderMode]["borderVertical"])))
            print(term.center("{bv}        {dap} {bv}".format(bv=specialChars[renderMode]["borderVertical"], dap=documentationAndPadding)))
          else:
            documentationAndPadding = padText(documentationHint, 56)
            print(term.center("{bv}        Documentation: {dap} {bv}".format(bv=specialChars[renderMode]["borderVertical"], dap=documentationAndPadding)))
          print(term.center(commonEmptyLine(renderMode)))
      print(term.center(commonEmptyLine(renderMode)))
      print(term.center(commonBottomBorder(renderMode)))

  def runSelection(selection):
    import types
    global nextCloudBuildOptions
    if len(nextCloudBuildOptions[selection]) > 1 and isinstance(nextCloudBuildOptions[selection][1], types.FunctionType):
      nextCloudBuildOptions[selection][1]()
    else:
      print(term.green_reverse('IOTstack Error: No function assigned to menu item: "{}"'.format(nodeRedBuildOptions[selection][0])))

  def isMenuItemSelectable(menu, index):
    if len(menu) > index:
      if len(menu[index]) > 2:
        if menu[index][2]["skip"] == True:
          return False
    return True

  def menuEntryPoint():
    # These need to be reglobalised due to eval()
    global currentMenuItemIndex
    global selectionInProgress
    global menuNavigateDirection
    global needsRender
    global hideHelpText
    global nextCloudBuildOptions
    term = Terminal()
    with term.fullscreen():
      menuNavigateDirection = 0
      mainRender(needsRender, nextCloudBuildOptions, currentMenuItemIndex)
      selectionInProgress = True
      with term.cbreak():
        while selectionInProgress:
          menuNavigateDirection = 0

          if needsRender: # Only rerender when changed to prevent flickering
            mainRender(needsRender, nextCloudBuildOptions, currentMenuItemIndex)
            needsRender = 0

          key = term.inkey(esc_delay=0.05)
          if key.is_sequence:
            if key.name == 'KEY_TAB':
              menuNavigateDirection += 1
            if key.name == 'KEY_DOWN':
              menuNavigateDirection += 1
            if key.name == 'KEY_UP':
              menuNavigateDirection -= 1
            if key.name == 'KEY_LEFT':
              goBack()
            if key.name == 'KEY_ENTER':
              runSelection(currentMenuItemIndex)
            if key.name == 'KEY_ESCAPE':
              return True
          elif key:
            if key == 'h': # H pressed
              if hideHelpText:
                hideHelpText = False
              else:
                hideHelpText = True
              mainRender(1, nextCloudBuildOptions, currentMenuItemIndex)

          if menuNavigateDirection != 0: # If a direction was pressed, find next selectable item
            currentMenuItemIndex += menuNavigateDirection
            currentMenuItemIndex = currentMenuItemIndex % len(nextCloudBuildOptions)
            needsRender = 2

            while not isMenuItemSelectable(nextCloudBuildOptions, currentMenuItemIndex):
              currentMenuItemIndex += menuNavigateDirection
              currentMenuItemIndex = currentMenuItemIndex % len(nextCloudBuildOptions)
    return True

  ####################
  # End menu section
  ####################


  if haltOnErrors:
    eval(toRun)()
  else:
    try:
      eval(toRun)()
    except:
      pass

# This check isn't required, but placed here for debugging purposes
global currentServiceName # Name of the current service
if currentServiceName == 'nextcloud':
  main()
else:
  print("Error. '{}' Tried to run 'nextcloud' config".format(currentServiceName))

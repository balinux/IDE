class IDE.MachineStateModal extends IDE.ModalView

  {
    Stopped, Running, NotInitialized, Terminated, Unknown,
    Starting, Building, Stopping, Rebooting, Terminating
  } = Machine.State

  constructor: (options = {}, data) ->

    options.cssClass or= 'ide-machine-state'
    options.width      = 440
    options.height     = 270

    super options, data

    @addSubView @container = new KDCustomHTMLView cssClass: 'content-container'
    @machine = @getData()

    unless @machine
      @state = options.state
      return @buildViews()

    {jMachine}   = @machine
    @machineName = jMachine.label
    @machineId   = jMachine._id
    {@state}     = @machine.status

    @buildViews()

    computeController = KD.getSingleton 'computeController'

    stateUpdater = (event) =>

      {status} = event
      return  if status is @state

      @state = status
      @buildViews()

    computeController.on "start-#{@machineId}", stateUpdater
    computeController.on "build-#{@machineId}", stateUpdater

    computeController.on "error-#{@machineId}", ({task, err})=>

      @_error = err.message  if err.message?
      stateUpdater { status: Unknown }

    @show()

  buildViews: ->
    @container.destroySubViews()

    @createStateLabel()

    if @state in [ Stopped, Running, NotInitialized, Terminated, Unknown ]
      @createStateButton()
    else if @state in [ Starting, Building, Stopping ]
      @createLoading()

    @createError()
    @createFooter()  unless @footer

  createStateLabel: ->
    stateTexts       =
      Stopped        : 'is turned off.'
      Starting       : 'is starting now.'
      Stopping       : 'is stopping now.'
      Running        : 'up and running.'
      Building       : 'is building now.'
      NotInitialized : 'is turned off.'
      Terminated     : 'is turned off.'
      Unknown        : 'is turned off.'
      NotFound       : 'This machine does not exist.' # additional class level state to show a modal for unknown routes.

    @label     = new KDCustomHTMLView
      tagName  : 'p'
      partial  : "<span class='icon'></span><strong>#{@machineName or ''}</strong> #{stateTexts[@state]}"
      cssClass : "state-label #{@state.toLowerCase()}"

    @container.addSubView @label

  createStateButton: ->
    @button      = new KDButtonView
      title      : 'Turn it on'
      cssClass   : 'turn-on state-button solid green medium'
      icon       : yes
      callback   : @bound 'turnOnMachine'

    if @state is 'Running'
      @button    = new KDButtonView
        title    : 'Start IDE'
        cssClass : 'start-ide state-button solid green medium'
        callback : @bound 'startIDE'

    @container.addSubView @button

  createLoading: ->
    @loader = new KDLoaderView
      showLoader : yes
      size       :
        width    : 40
        height   : 40

    @container.addSubView @loader

  createFooter: ->
    @footer    = new KDCustomHTMLView
      cssClass : 'footer'
      partial  : """
        <p>Free account VMs are shutdown when you leave Koding.</p>
        <a href="#" class="upgrade-link">Upgrade your account to keep it always on</a>
        <a href="#" class="info-link">More about VMs</a>
        <span class="more-icon"></span>
      """

    @addSubView @footer

  createError: ->
    return  unless @_error

    @errorMessage = new KDCustomHTMLView
      cssClass : 'error-message'
      partial  : """Failed to change state: #{@_error}"""

    @container.addSubView @errorMessage
    @_error = null

  turnOnMachine: ->
    computeController = KD.getSingleton 'computeController'
    computeController.fetchMachines (err) =>
      return KD.showError "Couldn't fetch machines"  if err

      methodName   = 'start'
      nextState    = 'Starting'

      if @state in [ NotInitialized, Terminated, Unknown ]
        methodName = 'build'
        nextState  = 'Building'

      computeController[methodName] @machine
      @state = nextState
      @buildViews()

  startIDE: ->
    @destroy()

    KD.getSingleton('computeController').fetchMachines (err, machines) =>
      return KD.showError "Couldn't fetch your VMs"  if err

      m = machine for machine in machines when machine._id is @machine._id

      KD.getSingleton('appManager').tell 'IDE', 'mountMachine', m
      @machine = m
      @setData m

      @emit 'IDEBecameReady'

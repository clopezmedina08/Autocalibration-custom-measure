# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class BPLLightingAndElectricEquipmentDefinitionsV2 < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return "BPL Lighting and electric equipment definitions V2"
  end

  # human readable description
  def description
    return "Set the lighting power density (W/ft^2), and electric equipment power density (W/ft^2) to a specified value for all spaces that have lights, electric equipment. This can be applied to the entire building or a specific space type"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Delete all of the existing lighting and electric equipment in the model. Add lighting and electric equipment with the user defined values to all spaces that initially had these loads, using the schedule from the original euipment. If multiple loads existed the schedule will be pulled from the one with the highest power density value."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make a choice argument for model objects
    space_type_handles = OpenStudio::StringVector.new
    space_type_display_names = OpenStudio::StringVector.new

    # putting model object and names into hash
    space_type_args = model.getSpaceTypes
    space_type_args_hash = {}
    space_type_args.each do |space_type_arg|
      space_type_args_hash[space_type_arg.name.to_s] = space_type_arg
    end

    # looping through sorted hash of model objects
    space_type_args_hash.sort.map do |key, value|
      # only include if space type is used in the model
      unless value.spaces.empty?
        space_type_handles << value.handle.to_s
        space_type_display_names << key
      end
    end

    # add building to string vector with space type
    building = model.getBuilding
    space_type_handles << building.handle.to_s
    space_type_display_names << '*All SpaceTypes*'
    space_type_handles << '0'
    space_type_display_names << '*None*'

    # make a choice argument for space type
    space_type = OpenStudio::Measure::OSArgument.makeChoiceArgument('space_type', space_type_handles, space_type_display_names)
    space_type.setDisplayName('Apply the Measure to a SINGLE SpaceType, ALL the SpaceTypes or NONE.')
    space_type.setDefaultValue('*All SpaceTypes*') # if no space type is chosen this will run on the entire building
    args << space_type

    # make a choice argument for model objects
    space_handles = OpenStudio::StringVector.new
    space_display_names = OpenStudio::StringVector.new

    # putting model object and names into hash
    space_args = model.getSpaces
    space_args_hash = {}
    space_args.each do |space_arg|
      space_args_hash[space_arg.name.to_s] = space_arg
    end

    # looping through sorted hash of model objects
    space_args_hash.sort.map do |key, value|
      space_handles << value.handle.to_s
      space_display_names << key
    end

    # add building to string vector with spaces
    building = model.getBuilding
    space_handles << building.handle.to_s
    space_display_names << '*All Spaces*'
    space_handles << '0'
    space_display_names << '*None*'

    # make a choice argument for space type
    space = OpenStudio::Measure::OSArgument.makeChoiceArgument('space', space_handles, space_display_names)
    space.setDisplayName('Apply the Measure to a SINGLE Space, ALL the Spaces or NONE.')
    space.setDefaultValue('*All Spaces*') # if no space type is chosen this will run on the entire building
    args << space

    # make an argument LPD
    lpd = OpenStudio::Measure::OSArgument.makeDoubleArgument('lpd', true)
    lpd.setDisplayName('Lighting Power Density (W/ft^2)')
    lpd.setDefaultValue(1.0)
    args << lpd

    # make an argument EPD
    epd = OpenStudio::Measure::OSArgument.makeDoubleArgument('epd', true)
    epd.setDisplayName('Electric Equipment Power Density (W/ft^2)')
    epd.setDefaultValue(1.0)
    args << epd

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    space_type_object = runner.getOptionalWorkspaceObjectChoiceValue('space_type', user_arguments, model)
    space_type_handle = runner.getStringArgumentValue('space_type', user_arguments)
    space_object = runner.getOptionalWorkspaceObjectChoiceValue('space', user_arguments, model)
    space_handle = runner.getStringArgumentValue('space', user_arguments)
    lpd = runner.getDoubleArgumentValue('lpd', user_arguments)
    epd = runner.getDoubleArgumentValue('epd', user_arguments)

    # find objects to change
    space_types = []
    spaces = []
    building = model.getBuilding
    building_handle = building.handle.to_s
    runner.registerInfo("space_type_handle: #{space_type_handle}")
    runner.registerInfo("space_handle: #{space_handle}")
    # setup space_types
    if space_type_handle == building_handle
      # Use ALL SpaceTypes
      runner.registerInfo('Applying change to ALL SpaceTypes')
      space_types = model.getSpaceTypes
    elsif space_type_handle == 0.to_s
      # SpaceTypes set to NONE so do nothing
      runner.registerInfo('Applying change to NONE SpaceTypes')
    elsif !space_type_handle.empty?
      # Single SpaceType handle found, check if object is good
      if !space_type_object.get.to_SpaceType.empty?
        runner.registerInfo("Applying change to #{space_type_object.get.name} SpaceType")
        space_types << space_type_object.get.to_SpaceType.get
      else
        runner.registerError("SpaceType with handle #{space_type_handle} could not be found.")
      end
    else
      runner.registerError('SpaceType handle is empty.')
      return false
    end

    # setup spaces
    if space_handle == building_handle
      # Use ALL Spaces
      runner.registerInfo('Applying change to ALL Spaces')
      spaces = model.getSpaces
    elsif space_handle == 0.to_s
      # Spaces set to NONE so do nothing
      runner.registerInfo('Applying change to NONE Spaces')
    elsif !space_handle.empty?
      # Single Space handle found, check if object is good
      if !space_object.get.to_Space.empty?
        runner.registerInfo("Applying change to #{space_object.get.name} Space")
        spaces << space_object.get.to_Space.get
      else
        runner.registerError("Space with handle #{space_handle} could not be found.")
      end
    else
      runner.registerError('Space handle is empty.')
      return false
    end

    # check the lpd for reasonableness
    if (lpd < 0) || (lpd > 50)
      runner.registerError("A Lighting Power Density of #{lpd} W/ft^2 is above the measure limit.")
      return false
    elsif lpd > 21
      runner.registerWarning("A Lighting Power Density of #{lpd} W/ft^2 is abnormally high.")
    end

    # check the epd for reasonableness
    if (epd < 0) || (epd > 50)
      runner.registerError("A Electric Equipment Power Density of #{epd} W/ft^2 is above the measure limit.")
      return false
    elsif epd > 21
      runner.registerWarning("A Electric Equipment Power Density of #{epd} W/ft^2 is abnormally high.")
    end

    # helper to make it easier to do unit conversions on the fly.  The definition be called through this measure.
    def unit_helper(number, from_unit_string, to_unit_string)
      converted_number = OpenStudio.convert(OpenStudio::Quantity.new(number, OpenStudio.createUnit(from_unit_string).get), OpenStudio.createUnit(to_unit_string).get).get.value
    end


    # short def to make numbers pretty (converts 4125001.25641 to 4,125,001.26 or 4,125,001). The definition be called through this measure
    def neat_numbers(number, roundto = 2) # round to 0 or 2)
      if roundto == 2
        number = format '%.2f', number
      else
        number = number.round
      end
      # regex to add commas
      number.to_s.reverse.gsub(/([0-9]{3}(?=([0-9])))/, '\\1,').reverse
    end


    # setup OpenStudio units that we will need
    unit_lpd_ip = OpenStudio.createUnit('W/ft^2').get
    unit_lpd_si = OpenStudio.createUnit('W/m^2').get
    unit_epd_ip = OpenStudio.createUnit('W/ft^2').get
    unit_epd_si = OpenStudio.createUnit('W/m^2').get

    # define starting units
    lpd_ip = OpenStudio::Quantity.new(lpd, unit_lpd_ip)
    epd_ip = OpenStudio::Quantity.new(epd, unit_epd_ip)

    # unit conversion of lpd from IP units (W/ft^2) to SI units (W/m^2)
    lpd_si = OpenStudio.convert(lpd_ip, unit_lpd_si).get
    epd_si = OpenStudio.convert(epd_ip, unit_epd_si).get

    # find most common lights schedule for use in spaces that do not have lights
    light_sch_hash = {}
    # add schedules or lights directly assigned to space
    model.getSpaces.each do |space|
      space.lights.each do |light|
        if light.schedule.is_initialized
          sch = light.schedule.get
          if light_sch_hash.key?(sch)
            light_sch_hash[sch] += 1
          else
            light_sch_hash[sch] = 1
          end
        end
      end
      # add schedule for lights assigned to space types
      if space.spaceType.is_initialized
        space.spaceType.get.lights.each do |light|
          if light.schedule.is_initialized
            sch = light.schedule.get
            if light_sch_hash.key?(sch)
              light_sch_hash[sch] += 1
            else
              light_sch_hash[sch] = 1
            end
          end
        end
      end
    end
    most_comm_sch = light_sch_hash.key(light_sch_hash.values.max)

    # find most common electric equipment schedule for use in spaces that do not have electric equipment
    elec_equip_sch_hash = {}
    # add schedules or electric equipment directly assigned to space
    model.getSpaces.each do |space|
      space.electricEquipment.each do |elec_equip|
        if elec_equip.schedule.is_initialized
          sch = elec_equip.schedule.get
          if elec_equip_sch_hash.key?(sch)
            elec_equip_sch_hash[sch] += 1
          else
            elec_equip_sch_hash[sch] = 1
          end
        end
      end
      # add schedule for electric equipment assigned to space types
      if space.spaceType.is_initialized
        space.spaceType.get.electricEquipment.each do |elec_equip|
          if elec_equip.schedule.is_initialized
            sch = elec_equip.schedule.get
            if elec_equip_sch_hash.key?(sch)
              elec_equip_sch_hash[sch] += 1
            else
              elec_equip_sch_hash[sch] = 1
            end
          end
        end
      end
    end
    most_comm_sch = elec_equip_sch_hash.key(elec_equip_sch_hash.values.max)



    # report initial condition
    building = model.getBuilding
    building_start_lpd_si = OpenStudio::Quantity.new(building.lightingPowerPerFloorArea, unit_lpd_si)
    building_start_lpd_ip = OpenStudio.convert(building_start_lpd_si, unit_lpd_ip).get
    building_start_epd_si = OpenStudio::Quantity.new(building.electricEquipmentPowerPerFloorArea, unit_epd_si)
    building_start_epd_ip = OpenStudio.convert(building_start_epd_si, unit_epd_ip).get
    runner.registerInitialCondition("The model's initial LPD is #{building_start_lpd_ip}, and initial EPD is #{building_start_epd_ip}.")

    # add if statement for NA if LPD = 0
    if building_start_lpd_ip.value <= 0
      runner.registerAsNotApplicable('The model has no lights, nothing will be changed.')
    end

    # add if statement for NA if EPD = 0
    if building_start_epd_ip.value <= 0
      runner.registerAsNotApplicable('The model has no electric equipment, nothing will be changed.')
    end

    # create a new LightsDefinition and new Lights object to use with setLightingPowerPerFloorArea
    template_light_def = OpenStudio::Model::LightsDefinition.new(model)
    template_light_def.setName("LPD #{lpd_ip} - LightsDef")
    template_light_def.setWattsperSpaceFloorArea(lpd_si.value)

    template_light_inst = OpenStudio::Model::Lights.new(template_light_def)
    template_light_inst.setName("LPD #{lpd_ip} - LightsInstance")

    # create a new ElectricEquipmentDefinition to use with setElectricEquipmentPowerPerFloorArea
    template_elec_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    template_elec_equip_def.setName("EPD #{epd_ip} - ElecEquipDef")
    template_elec_equip_def.setWattsperSpaceFloorArea(epd_si.value)

    template_elec_equip_inst = OpenStudio::Model::ElectricEquipment.new(template_elec_equip_def)
    template_elec_equip_inst.setName("EPD #{epd_ip} - ElecEquipInstance")

    # loop through space types
    space_types.each do |space_type|
      space_type_lights = space_type.lights
      space_type_spaces = space_type.spaces
      multiple_schedules = false

      space_type_lights_array = []

      # if space type has lights and is used in the model
      if !space_type_lights.empty? && !space_type_spaces.empty?
        lights_schedules = []
        space_type_lights.each do |space_type_light|
          lights_data_for_array = []
          if !space_type_light.schedule.empty?
            space_type_light_new_schedule = space_type_light.schedule
            if !space_type_light_new_schedule.empty?
              lights_schedules << space_type_light.powerPerFloorArea
              if !space_type_light.powerPerFloorArea.empty?
                lights_data_for_array << space_type_light.powerPerFloorArea.get
              else
                lights_data_for_array << 0.0
              end
              lights_data_for_array << space_type_light_new_schedule.get
              lights_data_for_array << space_type_light.isScheduleDefaulted
              space_type_lights_array << lights_data_for_array
            end
          end
        end

        # pick schedule to use and see if it is defaulted
        space_type_lights_array = space_type_lights_array.sort.reverse[0]
        if !space_type_lights_array.nil? # this is need if schedule is empty but also not defaulted
          if space_type_lights_array[2] != true # if not schedule defaulted
            preferred_schedule = space_type_lights_array[1]
          else
            # leave schedule blank, it is defaulted
          end
        end

        # flag if lights_schedules has more than one unique object
        if lights_schedules.uniq.size > 1
          multiple_schedules = true
        end

        # delete lights and luminaires and add in new light.
        space_type_lights = space_type.lights
        space_type_lights.each(&:remove)
        space_type_light_new = template_light_inst.clone(model)
        space_type_light_new = space_type_light_new.to_Lights.get
        space_type_light_new.setSpaceType(space_type)

        # assign preferred schedule to new lights object
        if defined? space_type_lights_array
          if space_type_light_new.schedule.empty? # && (space_type_lights_array[2] != true)
            space_type_light_new.setSchedule(preferred_schedule)
          end
        else
          runner.registerWarning("Not adding schedule for light in #{space_type.name}, no original light to harvest schedule from.")
        end

        # if schedules had to be removed due to multiple lights add warning
        if !space_type_light_new.schedule.empty? && (multiple_schedules == true)
          space_type_light_new_schedule = space_type_light_new.schedule
          runner.registerWarning("The space type named '#{space_type.name}' had more than one light object with unique schedules. The schedule named '#{space_type_light_new_schedule.get.name}' was used for the new LPD light object.")
        end

      elsif space_type_lights.empty? && !space_type_spaces.empty?
        runner.registerInfo("The space type named '#{space_type.name}' doesn't have any lights, none will be added.")
      end
    end

    # getting spaces in the model
    spaces = model.getSpaces

    # # get space types in model
    # if apply_to_building
    #   spaces = model.getSpaces
    # else
    #   if !space_type.spaces.empty?
    #     spaces = space_type.spaces # only run on a single space type
    #   end
    # end

    spaces.each do |space|
      space_lights = space.lights
      space_luminaires = space.luminaires
      space_space_type = space.spaceType
      if !space_space_type.empty?
        space_space_type_lights = space_space_type.get.lights
      else
        space_space_type_lights = []
      end

      # array to manage light schedules within a space
      space_lights_array = []

      # if space has lights and space type also has lights
      if !space_lights.empty? && !space_space_type_lights.empty?

        # loop through and remove all lights and luminaires
        space_lights.each(&:remove)
        runner.registerWarning("The space named '#{space.name}' had one or more light objects. These were deleted and a new LPD light object was added to the parent space type named '#{space_space_type.get.name}'.")

        space_luminaires.each(&:remove)
        if !space_luminaires.empty?
          runner.registerWarning('Luminaire objects have been removed. Their schedules were not taken into consideration when choosing schedules for the new LPD light object.')
        end

      elsif !space_lights.empty? && space_space_type_lights.empty?

        # inspect schedules for light objects
        multiple_schedules = false
        lights_schedules = []
        space_lights.each do |space_light|
          lights_data_for_array = []
          if !space_light.schedule.empty?
            space_light_new_schedule = space_light.schedule
            if !space_light_new_schedule.empty?
              lights_schedules << space_light.powerPerFloorArea
              if !space_light.powerPerFloorArea.empty?
                lights_data_for_array << space_light.powerPerFloorArea.get
              else
                lights_data_for_array << 0.0
              end
              lights_data_for_array << space_light_new_schedule.get
              lights_data_for_array << space_light.isScheduleDefaulted
              space_lights_array << lights_data_for_array
            end
          end
        end

        # pick schedule to use and see if it is defaulted
        space_lights_array = space_lights_array.sort.reverse[0]
        if !space_lights_array.nil?
          if space_lights_array[2] != true
            preferred_schedule = space_lights_array[1]
          else
            # leave schedule blank, it is defaulted
          end
        end

        # flag if lights_schedules has more than one unique object
        if lights_schedules.uniq.size > 1
          multiple_schedules = true
        end

        # delete lights and luminaires and add in new light.
        space_lights.each(&:remove)

        # space_lights.each do |light|
        #   light.remove
        # end

        # space_lights.each {|light| light.remove}

        space_luminaires.each(&:remove)
        space_light_new = template_light_inst.clone(model)
        space_light_new = space_light_new.to_Lights.get
        space_light_new.setSpace(space)

        # assign preferred schedule to new lights object
        if defined? space_type_lights_array
          if space_light_new.schedule.empty? # && (space_type_lights_array[2] != true)
            space_light_new.setSchedule(preferred_schedule)
          end
          # model.getLights.each do |light|
          #   if light.schedule.empty?
          #     light.setSchedule(preferred_schedule)
          #   end
          # end

        else
          runner.registerWarning("Not adding schedule for light in #{space.name}, no original light to harvest schedule from.")
        end

        # if schedules had to be removed due to multiple lights add warning here
        if !space_light_new.schedule.empty? && (multiple_schedules == true)
          space_light_new_schedule = space_light_new.schedule
          runner.registerWarning("The space type named '#{space.name}' had more than one light object with unique schedules. The schedule named '#{space_light_new_schedule.get.name}' was used for the new LPD light object.")
        end

      elsif space_lights.empty? && space_space_type_lights.empty?

        # add in light for spaces that do not have any with most common schedule
        # if add_instance_all_spaces && space.partofTotalFloorArea
        #   space_light_new = template_light_inst.clone(model)
        #   space_light_new = space_light_new.to_Lights.get
        #   space_light_new.setSpace(space)
        #   space_light_new.setSchedule(most_comm_sch)
        #   runner.registerInfo("Adding light to #{space.name} using #{most_comm_sch.name} as fractional schedule.")
        # else
        #   # issue warning that the space does not have any direct or inherited lights.
        #   runner.registerInfo("The space named '#{space.name}' does not have any direct or inherited lights. No light was added")
        # end

      end
    end

    # BEGINNING ELECTRIC EQUIP LOOP

    # loop through space types
    space_types.each do |space_type|
      space_type_electric_equipment = space_type.electricEquipment
      space_type_spaces = space_type.spaces
      multiple_schedules = false

      space_type_electric_equipment_array = []

      # if space type has electric equipment and is used in the model
      if !space_type_electric_equipment.empty? && !space_type_spaces.empty?
        electric_equipment_schedules = []
        space_type_electric_equipment.each do |space_type_elec_equip|
          electric_equipment_data_for_array = []
          if !space_type_elec_equip.schedule.empty?
            space_type_elec_equip_new_schedule = space_type_elec_equip.schedule
            if !space_type_elec_equip_new_schedule.empty?
              electric_equipment_schedules << space_type_elec_equip.powerPerFloorArea
              if !space_type_elec_equip.powerPerFloorArea.empty?
                electric_equipment_data_for_array << space_type_elec_equip.powerPerFloorArea.get
              else
                electric_equipment_data_for_array << 0.0
              end
              electric_equipment_data_for_array << space_type_elec_equip_new_schedule.get
              electric_equipment_data_for_array << space_type_elec_equip.isScheduleDefaulted
              space_type_electric_equipment_array << electric_equipment_data_for_array
            end
          end
        end

        # pick schedule to use and see if it is defaulted
        space_type_electric_equipment_array = space_type_electric_equipment_array.sort.reverse[0]
        if !space_type_electric_equipment_array.nil? # this is need if schedule is empty but also not defaulted
          if space_type_electric_equipment_array[2] != true # if not schedule defaulted
            preferred_schedule = space_type_electric_equipment_array[1]
          else
            # leave schedule blank, it is defaulted
          end
        end

        # flag if electric_equipment_schedules has more than one unique object
        if electric_equipment_schedules.uniq.size > 1
          multiple_schedules = true
        end

        # delete electric equipment and add in new electric equipment.
        space_type_electric_equipment = space_type.electricEquipment
        space_type_electric_equipment.each(&:remove)
        space_type_elec_equip_new = template_elec_equip_inst.clone(model)
        space_type_elec_equip_new = space_type_elec_equip_new.to_ElectricEquipment.get
        space_type_elec_equip_new.setSpaceType(space_type)

        # assign preferred schedule to new electric equipment object
        if defined? space_type_electric_equipment_array
          if space_type_elec_equip_new.schedule.empty? && # (space_type_electric_equipment_array[2] != true)
            space_type_elec_equip_new.setSchedule(preferred_schedule)
          end
        else
          runner.registerWarning("Not adding schedule for electric equipment in #{space_type.name}, no original electric equipment to harvest schedule from.")
        end

        # if schedules had to be removed due to multiple electric equipment add warning
        if !space_type_elec_equip_new.schedule.empty? && (multiple_schedules == true)
          space_type_elec_equip_new_schedule = space_type_elec_equip_new.schedule
          runner.registerWarning("The space type named '#{space_type.name}' had more than one electric equipment object with unique schedules. The schedule named '#{space_type_elec_equip_new_schedule.get.name}' was used for the new EPD electric equipment object.")
        end

      elsif space_type_electric_equipment.empty? && !space_type_spaces.empty?
        runner.registerInfo("The space type named '#{space_type.name}' doesn't have any electric equipment, none will be added.")
      end
    end

    # getting spaces in the model
    # spaces = model.getSpaces

    # get space types in model
    # if apply_to_building
    #   spaces = model.getSpaces
    # else
    #   if !space_type.spaces.empty?
    #     spaces = space_type.spaces # only run on a single space type
    #   end
    # end

    spaces.each do |space|
      space_electric_equipment = space.electricEquipment
      space_space_type = space.spaceType
      if !space_space_type.empty?
        space_space_type_electric_equipment = space_space_type.get.electricEquipment
      else
        space_space_type_electric_equipment = []
      end

      # array to manage electric equipment schedules within a space
      space_electric_equipment_array = []

      # if space has electric equipment and space type also has electric equipment
      if !space_electric_equipment.empty? && !space_space_type_electric_equipment.empty?

        # loop through and remove all electric equipment
        space_electric_equipment.each(&:remove)
        runner.registerWarning("The space named '#{space.name}' had one or more electric equipment objects. These were deleted and a new EPD electric equipment object was added to the parent space type named '#{space_space_type.get.name}'.")

      elsif !space_electric_equipment.empty? && space_space_type_electric_equipment.empty?

        # inspect schedules for electric equipment objects
        multiple_schedules = false
        electric_equipment_schedules = []
        space_electric_equipment.each do |space_elec_equip|
          electric_equipment_data_for_array = []
          if !space_elec_equip.schedule.empty?
            space_elec_equip_new_schedule = space_elec_equip.schedule
            if !space_elec_equip_new_schedule.empty?
              electric_equipment_schedules << space_elec_equip.powerPerFloorArea
              if !space_elec_equip.powerPerFloorArea.empty?
                electric_equipment_data_for_array << space_elec_equip.powerPerFloorArea.get
              else
                electric_equipment_data_for_array << 0.0
              end
              electric_equipment_data_for_array << space_elec_equip_new_schedule.get
              electric_equipment_data_for_array << space_elec_equip.isScheduleDefaulted
              space_electric_equipment_array << electric_equipment_data_for_array
            end
          end
        end

        # pick schedule to use and see if it is defaulted
        space_electric_equipment_array = space_electric_equipment_array.sort.reverse[0]
        if !space_electric_equipment_array.nil?
          if space_electric_equipment_array[2] != true
            preferred_schedule = space_electric_equipment_array[1]
          else
            # leave schedule blank, it is defaulted
          end
        end

        # flag if electric_equipment_schedules has more than one unique object
        if electric_equipment_schedules.uniq.size > 1
          multiple_schedules = true
        end

        # delete electric equipment and add in new electric equipment
        space_electric_equipment.each(&:remove)
        space_elec_equip_new = template_elec_equip_inst.clone(model)
        space_elec_equip_new = space_elec_equip_new.to_ElectricEquipment.get
        space_elec_equip_new.setSpace(space)

        # assign preferred schedule to new electric equipment object
        if defined? space_type_electric_equipment_array
          if space_elec_equip_new.schedule.empty? # && (space_type_electric_equipment_array[2] != true)
            space_elec_equip_new.setSchedule(preferred_schedule)
          end
        else
          runner.registerWarning("Not adding schedule for electric equipment in #{space.name}, no original electric equipment to harvest schedule from.")
        end

        # if schedules had to be removed due to multiple electric equipment add warning here
        if !space_elec_equip_new.schedule.empty? && (multiple_schedules == true)
          space_elec_equip_new_schedule = space_elec_equip_new.schedule
          runner.registerWarning("The space type named '#{space.name}' had more than one electric equipment object with unique schedules. The schedule named '#{space_elec_equip_new_schedule.get.name}' was used for the new EPD electric equipment object.")
        end

      elsif space_electric_equipment.empty? && space_space_type_electric_equipment.empty?

        # add in electric equipment for spaces that do not have any with most common schedule
        # if add_instance_all_spaces && space.partofTotalFloorArea
        #   space_elec_equip_new = template_elec_equip_inst.clone(model)
        #   space_elec_equip_new = space_elec_equip_new.to_ElectricEquipment.get
        #   space_elec_equip_new.setSpace(space)
        #   space_elec_equip_new.setSchedule(most_comm_sch)
        #   runner.registerInfo("Adding electric equipment to #{space.name} using #{most_comm_sch.name} as fractional schedule.")
        # else
        #   # issue warning that the space does not have any direct or inherited electric equipment.
        #   runner.registerInfo("The space named '#{space.name}' does not have any direct or inherited electric equipment. No electric equipment object was added")
        # end

      end
    end



    # # subtract demo cost of lights and luminaires that were not deleted so the demo costs are not counted
    # if demo_cost_initial_const
    #   light_defs.each do |light_def| # this does not loop through the new def (which is the desired behavior)
    #     demo_costs_of_baseline_objects += -1 * add_to_baseline_demo_cost_counter(light_def)
    #     puts "#{light_def.name},#{add_to_baseline_demo_cost_counter(light_def)}"
    #   end
    #   luminaire_defs.each do |luminaire_def|
    #     demo_costs_of_baseline_objects += -1 * add_to_baseline_demo_cost_counter(luminaire_def)
    #   end
    # end

    # # clean up template light instance. Will EnergyPlus will fail if you have an instance that isn't associated with a space or space type
    # template_light_inst.remove

    # # calculate the final lights and cost for initial condition.
    # light_defs = model.getLightsDefinitions # this is done again to get the new def made by the measure
    # luminaire_defs = model.getLuminaireDefinitions
    # final_lighting_cost = 0
    # final_lighting_cost += get_total_costs_for_objects(light_defs)
    # final_lighting_cost += get_total_costs_for_objects(luminaire_defs)

    # # add one time demo cost of removed lights and luminaires if appropriate
    # if demo_cost_initial_const == true
    #   building = model.getBuilding
    #   lcc_baseline_demo = OpenStudio::Model::LifeCycleCost.createLifeCycleCost('LCC_baseline_demo', building, demo_costs_of_baseline_objects, 'CostPerEach', 'Salvage', 0, years_until_costs_start).get # using 0 for repeat period since one time cost.
    #   runner.registerInfo("Adding one time cost of $#{neat_numbers(lcc_baseline_demo.totalCost, 0)} related to demolition of baseline objects.")

    #   # if demo occurs on year 0 then add to initial capital cost counter
    #   if lcc_baseline_demo.yearsFromStart == 0
    #     final_lighting_cost += lcc_baseline_demo.totalCost
    #   end
    # end

    # report final condition
    building_final_lpd_si = OpenStudio::Quantity.new(building.lightingPowerPerFloorArea, unit_lpd_si)
    building_final_lpd_ip = OpenStudio.convert(building_final_lpd_si, unit_lpd_ip).get
    building_final_epd_si = OpenStudio::Quantity.new(building.electricEquipmentPowerPerFloorArea, unit_epd_si)
    building_final_epd_ip = OpenStudio.convert(building_final_epd_si, unit_epd_ip).get
    runner.registerFinalCondition("Your model's final LPD is #{building_final_lpd_ip} and final EPD is #{building_final_epd_ip}. WARNING: EPD MAY BE REPORTED INACCURATELY AS OF 2/26/2024. CHECK LOAD DEFINITIONS IN OSM.")

    return true
  end
end

# this allows the measure to be used by the application
BPLLightingAndElectricEquipmentDefinitionsV2.new.registerWithApplication



###### (Automatically generated documentation)

# BPL Lighting and electric equipment definitions V2

## Description
Set the lighting power density (W/ft^2), and electric equipment power density (W/ft^2) to a specified value for all spaces that have lights, electric equipment. This can be applied to the entire building or a specific space type

## Modeler Description
Delete all of the existing lighting and electric equipment in the model. Add lighting and electric equipment with the user defined values to all spaces that initially had these loads, using the schedule from the original euipment. If multiple loads existed the schedule will be pulled from the one with the highest power density value.

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### Apply the Measure to a SINGLE SpaceType, ALL the SpaceTypes or NONE.

**Name:** space_type,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

**Choice Display Names** ["*All SpaceTypes*", "*None*"]


### Apply the Measure to a SINGLE Space, ALL the Spaces or NONE.

**Name:** space,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

**Choice Display Names** ["*All Spaces*", "*None*"]


### Lighting Power Density (W/ft^2)

**Name:** lpd,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false


### Electric Equipment Power Density (W/ft^2)

**Name:** epd,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false







vol_frac = 0.3

power = 1.1
E0 = 1.0
Emin = 1.0e-6

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  # final_generator = 'MoveRight'
  [Bottom]
    type = GeneratedMeshGenerator
    dim = 2
    nx = 80
    ny = 40
    xmin = 0
    xmax = 150
    ymin = 0
    ymax = 75
  []
  [left_load]
    type = ExtraNodesetGenerator
    input = Bottom
    new_boundary = left_load
    coord = '37.5 75 0'
  []
  [right_load]
    type = ExtraNodesetGenerator
    input = left_load
    new_boundary = right_load
    coord = '112.5 75 0'
  []
  [left_support]
    type = ExtraNodesetGenerator
    input = right_load
    new_boundary = left_support
    coord = '0 0 0'
  []
  [right_support]
    type = ExtraNodesetGenerator
    input = left_support
    new_boundary = right_support
    coord = '150 0 0'
  []
[]

[Variables]
  [disp_x]
  []
  [disp_y]
  []
[]

[AuxVariables]
  [mat_den]
    family = MONOMIAL
    order = CONSTANT
    initial_condition = 0.02
  []
  [sensitivity_one]
    family = MONOMIAL
    order = SECOND
    initial_condition = -1.0
  []
  [sensitivity_two]
    family = MONOMIAL
    order = SECOND
    initial_condition = -1.0
  []
  [total_sensitivity]
    family = MONOMIAL
    order = SECOND
    initial_condition = -1.0
  []
[]

[AuxKernels]
  [total_sensitivity]
    type = ParsedAux
    variable = total_sensitivity
    expression = '0.5*sensitivity_one + 0.5*sensitivity_two'
    coupled_variables = 'sensitivity_one sensitivity_two'
    execute_on = 'LINEAR TIMESTEP_END'
  []
[]

[Physics/SolidMechanics/QuasiStatic]
  [all]
    strain = SMALL
    add_variables = true
    incremental = false
  []
[]

[BCs]
  [no_y]
    type = DirichletBC
    variable = disp_y
    boundary = left_support
    value = 0.0
  []
  [no_x]
    type = DirichletBC
    variable = disp_x
    boundary = left_support
    value = 0.0
  []
  [no_y_right]
    type = DirichletBC
    variable = disp_y
    boundary = right_support
    value = 0.0
  []
[]

[Materials]
  [elasticity_tensor]
    type = ComputeVariableIsotropicElasticityTensor
    youngs_modulus = E_phys
    poissons_ratio = poissons_ratio
    args = 'mat_den'
  []
  [E_phys]
    type = DerivativeParsedMaterial
    # Emin + (density^penal) * (E0 - Emin)
    expression = '${Emin} + (mat_den ^ ${power}) * (${E0}-${Emin})'
    coupled_variables = 'mat_den'
    property_name = E_phys
  []
  [poissons_ratio]
    type = GenericConstantMaterial
    prop_names = poissons_ratio
    prop_values = 0.0
  []
  [stress]
    type = ComputeLinearElasticStress
  []
[]

[Preconditioning]
  [smp]
    type = SMP
    full = true
  []
[]

[UserObjects]
  # We do filtering in the subapps
  [update]
    type = DensityUpdate
    density_sensitivity = total_sensitivity
    design_density = mat_den
    volume_fraction = ${vol_frac}
    execute_on = MULTIAPP_FIXED_POINT_BEGIN
  []
[]

[Executioner]
  type = Transient
  solve_type = NEWTON
  petsc_options_iname = '-pc_type -pc_factor_mat_solver_package'
  petsc_options_value = 'lu superlu_dist'
  nl_abs_tol = 1e-10
  dt = 1.0
  num_steps = 25
[]

[Outputs]
  exodus = true
  [out]
    type = CSV
    execute_on = 'TIMESTEP_END'
  []
  print_linear_residuals = false
[]

[Postprocessors]
  [mesh_volume]
    type = VolumePostprocessor
    execute_on = 'initial timestep_end'
  []
  [total_vol]
    type = ElementIntegralVariablePostprocessor
    variable = mat_den
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [vol_frac]
    type = ParsedPostprocessor
    expression = 'total_vol / mesh_volume'
    pp_names = 'total_vol mesh_volume'
  []
  [sensitivity]
    type = ElementIntegralVariablePostprocessor
    variable = total_sensitivity
  []
[]

[MultiApps]
  [sub_app_one]
    type = TransientMultiApp
    input_files = single_subapp_one.i
  []
  [sub_app_two]
    type = TransientMultiApp
    input_files = single_subapp_two.i
  []
[]

[Transfers]
  # First SUB-APP
  # To subapp densities
  [subapp_one_density]
    type = MultiAppCopyTransfer
    to_multi_app = sub_app_one
    source_variable = mat_den # Here
    variable = mat_den
  []
  # From subapp sensitivity
  [subapp_one_sensitivity]
    type = MultiAppCopyTransfer
    from_multi_app = sub_app_one
    source_variable = Dc # sensitivity_var
    variable = sensitivity_one # Here
  []
  # Second SUB-APP
  # To subapp densities
  [subapp_two_density]
    type = MultiAppCopyTransfer
    to_multi_app = sub_app_two
    source_variable = mat_den # Here
    variable = mat_den
  []
  # From subapp sensitivity
  [subapp_two_sensitivity]
    type = MultiAppCopyTransfer
    from_multi_app = sub_app_two
    source_variable = Dc # sensitivity_var
    variable = sensitivity_two # Here
  []
[]

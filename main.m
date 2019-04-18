clear
clc
%% Load data
case_name = 'example_3bus';
[Mat_lines,Mat_buses] = load_network(case_name);
Mat_loads = load_load_impedance(case_name);
Mat_gens = csvread('cases/example_3bus/gen_data.csv', 1,1);
% Mat_convs = csvread('cases/example_3bus/conv_data.csv', 1,1);


%% -- INITIALIZATION -- %%

lines_size = size(Mat_lines, 1); % number of lines
buses_size = size(Mat_buses, 1); % number of buses
loads_size = size(Mat_loads, 1); % number of loads
gens_size  = size(Mat_gens, 1);  % number of gens
% convs_size = size(Mat_convs, 1); % number of DC converters

omega0 = 120*pi; %nominal angular frequency
j = [cos(pi/2), -sin(pi/2) 
    sin(pi/2) , cos(pi/2)]; % Rotational matrix of pi/2.

%Initialize Line matrices
L_lines = zeros(2*lines_size, 2*lines_size);
R_lines = zeros(2*lines_size, 2*lines_size);
Z_lines = zeros(2*lines_size, 2*lines_size);

%Initialize Incidence Matrix between lines and buses
E_inc = zeros(2*buses_size, 2*lines_size);

%Initialize Bus matrices
G_buses = zeros(2*buses_size, 2*buses_size);
C_buses = zeros(2*buses_size, 2*buses_size);
Y_buses = zeros(2*buses_size, 2*buses_size);

%Initialize load matrices
L_loads = zeros(2*loads_size, 2*loads_size);
R_loads = zeros(2*loads_size, 2*loads_size);
Z_loads = zeros(2*loads_size, 2*loads_size);

%Initialize Incidence Matrix between loads and buses
I_inc_loads = zeros(2*buses_size, 2*loads_size);

%Initialize generator matrices
M_gens = zeros(gens_size, gens_size);
D_gens = zeros(gens_size, gens_size);
L_gens = zeros(2*gens_size, 2*gens_size);
R_gens = zeros(2*gens_size, 2*gens_size);
Z_gens = zeros(2*gens_size, 2*gens_size);
Ell_gens = zeros(gens_size, 1);

%Initialize Incidence Matrix between gens and buses
I_inc_gens = zeros(2*buses_size, 2*gens_size);

% %Initialize converter matrices
% Gdc_convs = zeros(convs_size, convs_size);
% Cdc_convs = zeros(convs_size, convs_size);
% Rac_convs = zeros(2*convs_size, 2*convs_size);
% Lac_convs = zeros(2*convs_size, 2*convs_size);
% Zac_convs = zeros(2*convs_size, 2*convs_size);
% 
% 
% %Initialize Incidence Matrix between converter and buses
% I_inc_convs = zeros(2*buses_size, 2*convs_size);



%% -- CONSTRUCT MATRICES -- %%

%Construct Line matrices
for i=1:lines_size %For each line
   r_line = Mat_lines(i,1); %resistance of line i
   l_line = Mat_lines(i,2); %inductance of line i   
   R_lines(2*i-1:2*i, 2*i-1:2*i) = r_line*eye(2); %Resistance Matrix (dq) of line i
   L_lines(2*i-1:2*i, 2*i-1:2*i) = l_line*eye(2); %Inductance Matrix (dq) of line i
   Z_lines(2*i-1:2*i, 2*i-1:2*i) = R_lines(2*i-1:2*i, 2*i-1:2*i) ...
       + j*omega0*L_lines(2*i-1:2*i, 2*i-1:2*i); %Impedance matrix (dq) of line i  
end
inv_L_lines = pinv(L_lines); %Compute pseudo-inverse of L. Pseudo to account for lines with no inductance.

%Construct Incidence Matrix
for i=1:lines_size
    s_bus = Mat_lines(i,3); % sending bus of line i
    r_bus = Mat_lines(i,4); % receiving bus of line i
    E_inc(2*s_bus-1, 2*i-1) = 1; % sending component of d axis
    E_inc(2*r_bus-1, 2*i-1) = -1; % receiving component of d axis
    E_inc(2*s_bus, 2*i) = 1; % sending component of q axis
    E_inc(2*r_bus, 2*i) = -1; % receiving component of q axis
end

%Construct Bus matrices
for i=1:buses_size
    g_bus = Mat_buses(i,1); % conductance of bus i
    c_bus = Mat_buses(i,2); % capacitance of bus i
    G_buses(2*i-1:2*i, 2*i-1:2*i) = g_bus*eye(2); %Conductance Matrix (dq) of bus i
    C_buses(2*i-1:2*i, 2*i-1:2*i) = c_bus*eye(2); %Capacitance Matrix (dq) of bus i
    Y_buses(2*i-1:2*i, 2*i-1:2*i) =  G_buses(2*i-1:2*i, 2*i-1:2*i) ...
        + j*omega0*C_buses(2*i-1:2*i, 2*i-1:2*i); %Admittance Matrix (dq) of bus i
end
inv_C_buses = pinv(C_buses); %Compute inverse of C

% Construct load matrices
for i=1:loads_size %For each load
    bus_number = Mat_loads(i,1);
    r_load = Mat_loads(i,2); %resistance of load i
    l_load = Mat_loads(i,3); %inductance of load i   
    R_loads(2*i-1:2*i, 2*i-1:2*i) = r_load*eye(2); %Resistance Matrix (dq) of load i
    L_loads(2*i-1:2*i, 2*i-1:2*i) = l_load*eye(2); %Inductance Matrix (dq) of load i
    Z_loads(2*i-1:2*i, 2*i-1:2*i) = R_loads(2*i-1:2*i, 2*i-1:2*i) ...
        + j*omega0*L_loads(2*i-1:2*i, 2*i-1:2*i); %Impedance matrix (dq) of load i
    I_inc_loads(2*bus_number-1:2*bus_number, 2*i-1:2*i) = eye(2); % Incidence of load i connected to bus_number
end
inv_L_loads = pinv(L_loads); %Compute inverse of L

%Construct Gen Matrices
for i=1:gens_size %For each generator
    bus_number = Mat_gens(i,1); %bus location of generator i
    r_gen = Mat_gens(i,2); %series resistance of gen i
    l_gen = Mat_gens(i,3); %series inductance of gen i
    ell_gen = Mat_gens(i,4); %mutual inductance between rotor and stator of gen i
    m_gen = Mat_gens(i,5); %inertia constant of gen i
    d_gen = Mat_gens(i,6); %damping constant of gen i
    
    Ell_gens(i) = ell_gen; %Mutual inductance of generator i
    M_gens(i,i) = m_gen; %Inertia constant of generator i
    D_gens(i,i) = d_gen; %Damping constant of generator i
    
    R_gens(2*i-1:2*i, 2*i-1:2*i) = r_gen*eye(2); %Resistance Matrix (dq) of gen i
    L_gens(2*i-1:2*i, 2*i-1:2*i) = l_gen*eye(2); %Inductance Matrix (dq) of gen i
    Z_gens(2*i-1:2*i, 2*i-1:2*i) = R_gens(2*i-1:2*i, 2*i-1:2*i) ...
        + j*omega0*L_gens(2*i-1:2*i, 2*i-1:2*i); %Impedance matrix (dq) of gen i
    
    I_inc_gens(2*bus_number-1:2*bus_number, 2*i-1:2*i) = eye(2); % Incidence of gen i connected to bus_number
end
inv_L_gens = pinv(L_gens); %Compute inverse of L
inv_M_gens = pinv(M_gens); %Compute inverse of M    

% %Construct Converter Matrices
% for i=1:convs_size %For each converter
%    bus_number = Mat_convs(i,1); %bus location of converter i
%    rac_conv = Mat_convs(i,2); %series resistance of AC output filter of converter i 
%    lac_conv = Mat_convs(i,3); %series inductance of AC output filter of converter i
%    gdc_conv = Mat_convs(i,4); %parallel conductance of DC current input source of converter i
%    cdc_conv = Mat_convs(i,5); %parallel capacitance of DC current input source of converter i
%    
%    Gdc_convs(i,i) = gdc_conv; %Conductance of DC side of converter i
%    Cdc_convs(i,i) = cdc_conv; %Capacitance of DC side of converter i
%    
%    Rac_convs(2*i-1:2*i, 2*i-1:2*i) = rac_conv*eye(2); %Resistance Matrix (dq) of output filter of converter i
%    Lac_convs(2*i-1:2*i, 2*i-1:2*i) = lac_conv*eye(2); %Inductance Matrix (dq) of output filter of converter i
%    Zac_convs(2*i-1:2*i, 2*i-1:2*i) = Rac_convs(2*i-1:2*i, 2*i-1:2*i) ...
%         + j*omega0*Lac_convs(2*i-1:2*i, 2*i-1:2*i); %Impedance matrix (dq) of output filter of converter i
%     
%     
%    I_inc_convs(2*bus_number-1:2*bus_number, 2*i-1:2*i) = eye(2); % Incidence of converter i connected to bus_number 
% end
% inv_Cdc_convs = pinv(Cdc_convs); %Compute inverse of Cdc
% inv_Lac_convs = pinv(Lac_convs); %Compute inverse of Lac


%% -- Define a parameter struct to handle all the data -- %%

%Base data
param.omega0 = omega0;
param.j = j;

%Lines
param.R_lines = R_lines;
param.L_lines = L_lines;
param.Z_lines = Z_lines;
param.inv_L_lines = inv_L_lines;
param.E_inc = E_inc;

%Buses
param.G_buses = G_buses;
param.C_buses = C_buses;
param.Y_buses = Y_buses;
param.inv_C_buses = inv_C_buses;

%Loads
param.R_loads = R_loads;
param.L_loads = L_loads;
param.Z_loads = Z_loads;
param.inv_L_loads = inv_L_loads;
param.I_inc_loads = I_inc_loads;

%Generators
param.M_gens = M_gens;
param.D_gens = D_gens;
param.L_gens = L_gens;
param.inv_L_gens = inv_L_gens;
param.inv_M_gens = inv_M_gens;
param.R_gens = R_gens;
param.Z_gens = Z_gens;
param.Ell_gens = Ell_gens;
param.I_inc_gens = I_inc_gens;

% %Converters
% param.Gdc_convs = Gdc_convs;
% param.Cdc_convs = Cdc_convs;
% param.inv_Cdc_convs = inv_Cdc_convs;
% param.Rac_convs = Rac_convs;
% param.Lac_convs = Lac_convs;
% param.inv_Lac_convs = inv_Lac_convs;
% param.Zac_convs = Zac_convs;
% para.I_inc_convs = I_inc_convs;

%% Size of state and input vectors

convs_size = 0;

num_variables = 2*gens_size + 2*convs_size + 2*loads_size + 2*lines_size + 2*buses_size ... %AC variables [i_g,i_c, i_l, i_t, v]
    + gens_size + gens_size + convs_size ; %DC variables [theta_g, omega_g, v_dc] %Total variables

num_inputs = gens_size + gens_size + convs_size + 2*convs_size; % Inputs [tau_m, i_f, i_dc, m]

%% Split size of state vector

%AC states
i_gens_size = size(Z_gens,1); % number of current of gens variables (2*gens)
% iac_convs_size = size(Zac_convs,1) % number of current of conv vars (2*convs)
iac_conv_size = 0;
i_loads_size = size(Z_loads,1); % number of current of loads variables (2*loads)
i_lines_size = size(Z_lines,1); %obtain number of current of lines variables (2*lines)
v_buses_size = size(Y_buses,1); %obtain number of voltage of buses variables (2*buses)

%DC states
theta_gens_size = size(inv_M_gens,1); %number of angle of gens variables (gens)
omega_gens_size = size(inv_M_gens,1); %number of freq of gens variables (gens)
% vdc_convs_size = size(Gdc_convs,1); %number of vdc of convs variables (convs)
vdc_convs_size = 0;
iac_convs_size = 0;

tau_m_size = theta_gens_size; %number of inputs of tau_m
i_f_size = theta_gens_size; %number of inputs of i_f
% idc_convs_size = vdc_convs_size; %number of inputs of i_dc
% m_convs_size = 2*vdc_convs_size; %number of inputs of modulation signal m

%% Split the state vector and input vector

% -- Obtain the limits of the state vector -- %
% AC variables
param_limits.i_gens_init = 1;
param_limits.i_gens_end = param_limits.i_gens_init + i_gens_size - 1;
% param_limits.iac_convs_init = param_limits.i_gens_end + 1;
% param_limits.iac_convs_end = param_limits.iac_conv_init + iac_conv_size -1;
param_limits.iac_convs_end = param_limits.i_gens_end; % no converters case
param_limits.i_loads_init = param_limits.iac_convs_end + 1;
param_limits.i_loads_end = param_limits.i_loads_init + i_loads_size -1;
param_limits.i_lines_init = param_limits.i_loads_end + 1;
param_limits.i_lines_end = param_limits.i_lines_init + i_lines_size -1;
param_limits.v_buses_init = param_limits.i_lines_end+1;
param_limits.v_buses_end = param_limits.v_buses_init + v_buses_size -1;

% DC variables
param_limits.theta_gens_init = param_limits.v_buses_end + 1;
param_limits.theta_gens_end = param_limits.theta_gens_init + theta_gens_size -1;
param_limits.omega_gens_init = param_limits.theta_gens_end + 1;
param_limits.omega_gens_end = param_limits.omega_gens_init + omega_gens_size -1;
% param_limits.vdc_convs_init = param_limits.omega_gens_end + 1;
% param_limits.vdc_convs_end = param_limits.vdc_convs_init + vdc_convs_size -1;


% -- Obtain the limits of the input vector -- %
param_limits.tau_m_init = 1;
param_limits.tau_m_end = param_limits.tau_m_init + tau_m_size - 1;
param_limits.i_f_init = param_limits.tau_m_end + 1;
param_limits.i_f_end = param_limits.i_f_init + i_f_size -1;
% param_limits.idc_convs_init = param_limits.i_f_end + 1;
% param_limits.idc_convs_end = param_limits.idc_convs_init + idc_convs_size -1;
% param_limits.m_convs_init = param_limits.idc_convs_end + 1;
% param_limits.m_convs_end = param_limits.m_convs_init + m_convs_size -1;



%% Solve differential equation

tspan = [0,0.6];
%x0 = 0.01*ones(num_variables, 1); %initial condition
x0 = [ 0.5; 0.5; 0.5; 0.5; %i_gen
    0.5; 0.5; 0.5; 0.5; 0.5; 0.5; %i_load
    0.1; 0.1; 0.1; 0.1; 0.1; 0.1; %i_line
    1; 1; 1; 1; 1; 1; %v_buses
    0.2; 0.3;  %theta_gen
    1; 1]; %omega_gen
u = zeros(num_inputs, 1);
u = [1.2; 1.1; ... % tau_m
    1; 1]; % i_f 
Mass_Matrix = eye(num_variables);
options = odeset('Mass', Mass_Matrix);

%Solve differential equation system. You can pass parameters to the
%function using this technique
[t,x] = ode15s(@(t,x)ode_full_system_modular(t,x,u,param, param_limits), tspan, x0, options);
%[t,x] = ode23t(@(t,x)ode_full_system_modular(t,x,u,param, param_limits), tspan, x0);

plot(t,x)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% AE4320 System Identification of Aerospace Vehicles 21/22
% Assignment: Neural Networks
% 
% Part 2 Code: State & Parameter Estimation
% Date: 28 OCT 2022
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

close all 
clear
clc

app_chart = 1;
save_chart = 0;

%% Load Data

data_f16 = 'Datafile/F16traindata_CMabV_2022';

%%% Retrieve Variables Cm, Uk, Zk and split them up 
[Uk, Zk, Cm] = load_data_f16(data_f16);

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Start of State Estimation using IEKF
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%{  
    Part 2.1 - General overview of f16 state and output system eqs
    1) System State Equation: xdot(t) = f(x(t), u(t), t)
        > State Vector: x(t) = [u v w C_alpha_up]
        > Input Vector: u(t) = [udot, vdot, wdot]
    
    2) Measurement (Output) Equation: z(t) = h(x(t), u(t), t)
        > Output vector: z(t) = [alpha_m beta_m V_m]
        > Additional + [v_alpha v_beta v_V] as white noise 
%}

%%% Parameters

%%% states + input
states = 4; % u, w, v, C_alpha_up
input = 3; % udot, wdot, vdot

%%% Time data
N = size(Zk, 2)-1; % Number of sampling data
tstart = 0;
dt = 0.01; % sampling rate
tend = dt*N; % usually equal to N, but takes longer to load
tspan = tstart:dt:tend; % tspan needed for numerical integration later

%%% Process(w) + Sensor(v) Noise Statistics 
Ew = zeros(1, states); % Expectation Process Noise
sigma_w = [1e-3 1e-3 1e-3 0]; % std. dev. 
Q = diag(sigma_w.^2); % E(w*wT)

Ev = zeros(1, input);  % Expectation White Noise
sigma_v = [0.035 0.013 0.110]; 
R = diag(sigma_v.^2); % E(v*vT)

%% Nonlinear System Analysis + IEKF (Part 2.3)
%%% Check if observability matrix is full ranked in order to apply KF
observ_check

%%% Apply IEKF
[X_est_k1k1, Z_k1k_biased, IEKF_count] = func_IEKF(Uk, Zk, dt, sigma_w, sigma_v);

%% Reconstruction of alpha_true using upwash bias (Part 2.4)



function [X_k1k1, Z_k1k1, IEKF_count, est_err] = func_IEKF(Sx, Zk, Uk)

%{
    Function that applies the Iterated Extended Kalman Filter (IEKF)
    > The input are stated in the main file
    > The outputs:
        - X_k1k1: One-Step-Ahead (K+1,K+1) Optimal State Estimation Vector 
        - Z_k1k1: One-Step-Ahead (K+1,K) Measurement Prediction
        Vector
        - IEKF Count: Number of Iterative Measurement Cycles for X_est_k1k1
%}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% IEKF Integration and Simulation Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Sampling data
states = 4; % u, w, v, C_alpha_up
input = 3; % udot, wdot, vdot
N = size(Uk, 2); % Number of sampling data
ti = 0;
dt = 0.01; % sampling rate

% Process(w) + Sensor(v) Noise Statistics 
Ew = zeros(states, 1); % Expectation Process Noise
sigma_w = [1e-3 1e-3 1e-3 0]; % std. dev. 
Q = diag(sigma_w.^2); % E(w*wT)
wk = Q*randn(states, N) + Ew.*ones(states, N); % wu, wv, ww, wc

Ev = zeros(input, 1);  % Expectation White Noise
sigma_v = [0.035 0.013 0.110]; 
R = diag(sigma_v.^2); % E(v*vT)
vk = R*randn(input, N) + Ev.*ones(input, N); % va, vb, vv

% Adding internal system processing noise
Sx = Sx + wk;

% Input for discretisation of the continuous time system 
G = zeros(states); % noise input matrix
B = eye(states); % input matrix B

% IEKF Parameters
epsilon = 1e-10; % error range for iterative part
apply_iter = 1; % binary switch for iteration -> apply IEKF
max_iter = 100; % Max. number of iterations possible

x0 = [Zk(3,1); 0; 0; 0]; % initial values for states
P0 = 0.01 * diag(ones(1, states)); % Initial estimate for the Cov. Matrix of State Prediction error

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Define arrays and matrices to store results
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Output params 
X_k1k1 = zeros(states, N);
Z_k1k1 = zeros(input, N);
IEKF_count = zeros(N, 1);  % Iteration count for each data point
est_err = [];

% Initial Conditions
x_k1k1 = x0;
P_k1k1 = P0; 

Z_k1k1(:,1) = calc_h(x_k1k1, vk(:,1));
X_k1k1(:,1) = x_k1k1; 

%%% Run IEKF Process
disp('Kalman Filtering on Measured Data');
tic; % record current time

% Run the IEKF through all N Measurements
for k = 2:N
    % One-Step Ahead Prediction of X_k1k using system ODEs
    [ti, X_k1k] = ode45(@(t, x) calc_F(t, x, Sx(:,k-1)), [ti ti+dt], x_k1k1); 
    
    % Obtain data from last row
    ti = ti(end); 
    X_k1k = X_k1k(end,:)'; 
    
    % One-Step Ahead Prediction Output (z_k1k)
    z_k1k = calc_h(X_k1k, vk(:,k)); 

    % Discretize the continuous time system (part of EKF)
    Fx = zeros(states, states); 
    
    [~, Psi] = c2d(Fx, B, dt); 
    [Phi, Gamma] = c2d(Fx, G, dt); 
    
    % Cov. Matrix of State pred. error P_k1k
    P_k1k = Phi*P_k1k1*Phi' + Gamma*Q*Gamma'; 
    
    
    %%% IEKF Iterative Part: Set Iteration Values & Initial Conditions
    
    % if apply_iter = 1: apply IEKF, else run standard EKF
    if (apply_iter)
        eta2 = X_k1k; % init the iteration with state estimation calc before
        err_iter = 2*epsilon;
        N_iter = 0; 
        
        while (err_iter > epsilon) 
            
            if (N_iter >= max_iter)
                fprintf('Terminating IEKF: exceeded max iterations (%d)\n', max_iter);
                break
            end
            
            N_iter = N_iter + 1;
            eta1 = eta2;

            % Reconstruct the Jacobian H = d/dx(h(x))) with h(x) the observation model transition matrix 
            Hx = calc_Hx(eta1); 
           
            % The innovation matrix
            Ve = (Hx*P_k1k*Hx' + R);

            % The Kalman gain matrix 
            K = P_k1k * Hx' / Ve;
            
            % Observation State for current loop 
            z_current = calc_h(eta1, vk(:,k)) ; 

            eta2 = X_k1k + K * (Zk(:,k) - z_current - Hx*(X_k1k - eta1));
            err_iter = norm((eta2 - eta1), inf) / norm(eta1, inf);
        end

        IEKF_count(k) = N_iter;
        x_k1k1 = eta2; % new IC for next iteration

    else % normal EKF
        
        % Correction
        Hx = calc_Hx(X_k1k); % perturbation of h(x,u,t)
        % Pz(k+1|k) (covariance matrix of innovation)
        Ve = (Hx*P_k1k * Hx' + R); 

        % K(k+1) (gain)
        K = P_k1k * Hx' / Ve;
        % Calculate optimal state x(k+1|k+1) 
        x_k1k1 = X_k1k + K * (Zk(:,k) - z_k1k); 

    end
        
    % Save data 
    X_k1k1(:,k) = x_k1k1;
    P_k1k1 = (eye(states) - K*Hx) * P_k1k * (eye(states) - K*Hx)' + K*R*K'; 
    
    % Corrected Measurement
    Z_k1k1(:,k) = calc_h(x_k1k1, vk(:,k));
    est_err = [est_err, (x_k1k1 - X_k1k)];
       
end % end of for loop 

end % end of function

function output = simNet_RBF(struct, input)

%{
    Function that trains the neural network based on several activation
    functions:
    > Linear Regression (linregress)
    > Levenberg-Marquardt (lm)
%}

%%% Data basic preprocessing using normalization to scale X and Y. 
[output, Xtrain_norm, Ytrain_norm] = predata_norm(struct, input.X_train, input.Y_train); 

%%% Choose and Start Training Algorithm
switch struct.trainAlg
    
    case 'linregress' 
        
        [idx, centroid] = kmeans(Xtrain_norm, struct.N_hidden); % get clustered neuron centroid locations
        output.centers = centroid;
       
        %%% Input Layer - obtain Vj struct from input layer
        vj = calc_vj(output, Xtrain_norm);
        
        %%% Activitation function given by phi_j(vj) = a*exp(-vj) 
        phi_j = exp(-vj); 
        output.Wjk = pinv(phi_j) * Ytrain_norm; % get the hidden-output layer weights
        
        %%% Get estimated struct for each dataset using obtained Wjk
        [Y_est_train, phi_j_train, vj_train, R_train] = output_sim(output, input.X_train);
        [Y_est_test, phi_j_test, vj_test, R_test] = output_sim(output, input.X_test);
        [Y_est_val, phi_j_val, vj_val, R_val] = output_sim(output, input.X_val);
        
        %%% Obtain the model error using MSE between measured Y set and
        %%% Y_est 
        output.results.MSE_train = MSE_output(input.Y_train, Y_est_train); 
        output.results.MSE_test = MSE_output(input.Y_test, Y_est_test); 
        output.results.MSE_val = MSE_output(input.Y_val, Y_est_val); 
        
    case 'levenmarq'
        
        %%% Learning algorithm: adaptive learning rate: Levenberg-Marquardt
        
        %%% Initialization of parameters
        Et = zeros(struct.epochs, 1); % Cost Function Et 
        MSE = zeros(struct.epochs, size(input.X, 2)); % MSE for each dataset per epoch
        
        %%% Get centroids for RBF
        [idx, centroid] = kmeans(Xtrain_norm, struct.N_hidden); % get clustered neuron centroid locations
        output.centers = centroid;
        
        %%% stop loop conditions
        early_stop = 0;
        
        %%% Looping through epochs 
        
        for epochs = 1:struct.epochs
            %%% Feedforward to obtain MSE for backpropagation process
            Y_est_train = output_sim(output, Xtrain_norm);
            
            %%% Compute cost function value Et 
            Et_epoch = MSE_output(Ytrain_norm, Y_est_train);
            
            Et(epochs) = Et_epoch; % store for each epoch
            
            %%% Obtain weight update: w_t1 = wt-(J'*J+mu*I)^-1*J'*e
            
            % Compute the Jacobian Matrix J 
            [J, err] = calc_J(output, Xtrain_norm, Ytrain_norm);
            
            % Compute Hessian matrix transposed(J)*J
            H = J'*J; 
            
            % Reshape weights into an one-liner
            wt = reshape([struct.Wij' struct.Wjk], 1, struct.N_weights);
            
            % From weight update w_t1 equation
            w_t1 = wt - ((H + struct.mu * eye(size(H))) \ (J' * err))';
            
            % Updated Weights
            w_t1_update = reshape(w_t1, struct.N_hidden, struct.N_input + struct.N_output);
            output.Wij = w_t1_update(:, 1:struct.N_input)';
            output.Wjk = w_t1_update(:, end);
            
            % Get the error output using the updated weights
            Ytrain_update = output_sim(output, Xtrain_norm);
            err_update = MSE_output(Ytrain_norm, Ytrain_update);
            
            %%% Apply adaptive learning rate algo based on updated error
            while err_update > err
                % if updated error is bigger than previous error - increase
                % learning rate
                struct.mu = struct.mu * struct.mu_inc;
                
                % Weight update given new learning rate
                w_t1 = wt - ((H + struct.mu * eye(size(H))) \ (J' * err))';
                w_t1_update = reshape(w_t1, struct.N_hidden, struct.N_input + struct.N_output);
                output.Wij = w_t1_update(:, 1:struct.N_input)';
                output.Wjk = w_t1_update(:, end);
                
                % Get new updated error for new weights
                Ytrain_update = output_sim(output, Xtrain_norm);
                err_update = MSE_output(Ytrain_norm, Ytrain_update);
            end
            
            output.Wij = w_t1_update(:, 1:struct.N_input)';
            output.Wjk = w_t1_update(:, end);
            
            %%% Get results for each dataset
            [Y_est_train, phi_j_train, vj_train, R_train] = output_sim_linreg(output, input.X_train);
            [Y_est_test, phi_j_test, vj_test, R_test] = output_sim_linreg(output, input.X_test);
            [Y_est_val, phi_j_val, vj_val, R_val] = output_sim_linreg(output, input.X_val);
            
            %%% MSE
            MSE(epochs, 1) = MSE_output(input.Y_train, Y_est_train); 
            MSE(epochs, 2) = MSE_output(input.Y_test, Y_est_test); 
            MSE(epochs, 3) = MSE_output(input.Y_val, Y_est_val); 
            
            %%% Determine requirements to stop the loop
            [stop, early_stop, output] = stop_condition(struct, epochs, Et, MSE, early_stop);
                
            if stop
                break
            end      
        end
        
        % Compute cost function value Et and weight update dW for current
        % set of weights Wt and eta (learning rate)
        
        
        % Perform update of weights and compute new cost function E_t1
        
        % if E_t1 < Et then accept changes and increase learning rate
        
        % if eta_t1 = eta_t * alpha else do not accept changes and decrease
        % learning rate eta_t1 = eta_t * inv(alpha)
        
        % Stop loop if partial derivatives are nearly 0 
         
        
end
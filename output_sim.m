function [Y_est, phi_j, vj, R] = output_sim(struct, X)

%{ 
    Function that simulates the RBF neural network using the obtained Wjk weights
    to obtain the estimated output hypothesis.
%} 

%%% Normalization preprocessing

if isequal(struct.trainAlg, 'linregress')
    [struct, X_norm] = predata_norm(struct, X);
elseif isequal(struct.trainAlg, 'levenmarq')
    X_norm = X; 
end


%%% Obtain vj - function from input to hidden
[vj, R] = calc_vj(struct, X_norm);

%%% Use the RBF activation function to get output of the hidden layer
phi_j = exp(-vj);

%%% Use output of the hidden layer to get vk (function of Wjk and output of
%%% hidden layer). In equation form: vk = sum_j(ajk * phi_j)
vk = phi_j * struct.Wjk;

%%% Output layer neuron Y (purelin transfer function)
Y_est_norm = vk;

if isequal(struct.trainAlg, 'linregress')
    %%% Reverse normalization for Y_est_norm output
    Y_est = mapminmax('reverse', Y_est_norm', struct.postdata);
    Y_est = Y_est'; 
elseif isequal(struct.trainAlg, 'levenmarq')
    Y_est = Y_est_norm;
end

end
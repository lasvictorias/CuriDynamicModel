function tau_e = electricalTorque(theta_g, i_g, i_f, l_m)
%This function represents electrical torque of the generator based off Equation (5) in Curi Paper

tau_e = -l_m * i_f* i_g' * [ cos(pi/2) -sin(pi/2); sin(pi/2) cos(pi/2)]*[cos(theta_g); sin(theta_g)];
end
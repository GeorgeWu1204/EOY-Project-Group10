clear

Ts = 0.1e-6;                        %Sample time for the model. Do not Change.
Fsw = 62000;                        %Switching frequency of the PWM
Run_Time = 100e-3;                  %Amount of time to simulate

% Vin = 5;                            %Input Voltage

Cout = 1000e-6;                     %Output Capacitance (1000e-6 is on your board)

L = 100e-6;                         %Inductance (100e-6 is on your board)

Nch_Ron = 0.115;                    %MOSFET On-state resistance (from Datasheet)
Nch_Vd = 1.5;                       %MOSFET parallel diode voltage (from Datasheet)

Vf_Diode = 0.7;                     %Diode Forward Voltage

Duty = 50;                          %Duty Cycle command
Rload = 120;                         %Load resistance

Irradiance = 500;
Temperature = 25;

sim("MPPT_Boost",Run_Time);
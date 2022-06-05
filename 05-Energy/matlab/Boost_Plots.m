%The data output is called "ans" if the model is run from within a script
%but "out" when you run it by pressing the play button, account for that
%here
Sim_Data = ans;

%Not all plots need the full time range, this sets up a 0.1ms plot length
%and calculates the required number of samples
Plot_Length = 1e-4;
Plot_Points = round(Plot_Length/Ts);

%For this case, the plot is the last 0.1ms so the "end" function is used to
%select these, the time values are then offset by the first value (meaning
%they run from 0 - 0.1ms rather than starting at the runtime - 0.1ms
Time_Values = Sim_Data.Diode_Scope.time(end-Plot_Points:end)-Sim_Data.Diode_Scope.time(end-Plot_Points);

%Collating some data here, there are a number of available scopes and each
%can have multiple value sets type "Sim_Data" into the command console to
%see what is available to plot
Diode_current = Sim_Data.Diode_Scope.signals(1).values(end-Plot_Points:end);
MOSFET_current = Sim_Data.MOSFET_Scope.signals(1).values(end-Plot_Points:end);
MOSFET_voltage = Sim_Data.MOSFET_Scope.signals(2).values(end-Plot_Points:end);
IL = Sim_Data.IL_Scope.signals(1).values(end-Plot_Points:end);

Output_voltage = Sim_Data.Vout_Scope.signals(1).values(end-Plot_Points:end);

Diode_voltage = Sim_Data.Diode_Scope.signals(2).values(end-Plot_Points:end);

%Plot some things: I have set up a number of plots here as examples, not as
%as complete set of things you may wish to plot. A number of different
%figure and output file formats are used as examples also. Matlabs help
%files are VERY GOOD for figuring out how this stuff works

figure
subplot(2,1,1)
plot(Time_Values, Diode_current,'b',Time_Values, MOSFET_current,'r')
% ylim([0 1.5])
ylabel('Current (A)')
legend('Diode Iak','MOSFET Ids','Location','southeast')

subplot(2,1,2)
plot(Time_Values, IL)
% ylim([0 1.5])
ylabel('Inductor Current (A)')
xlabel('Time (s)')

%This is a print function that exports a PDF
exportgraphics(gcf,'Boost_fig1.pdf','ContentType','vector')


figure
subplot(3,1,1)
plot(Time_Values, Output_voltage)
%ylim([5.7 5.85])
ylabel('Output Voltage (V)')

subplot(3,1,2)
plot(Time_Values, Diode_voltage)
%ylim([0.65 0.9])
ylabel('MOSFET Voltage (V)')
xlabel('Time (s)')

subplot(3,1,3)
plot(Time_Values, Diode_voltage)
%ylim([0.65 0.9])
ylabel('Diode Voltage (V)')
xlabel('Time (s)')

%This is a print function that exports a jpg
exportgraphics(gcf,'Boost_fig2.jpg','Resolution',300)
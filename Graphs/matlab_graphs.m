
close all
set(groot,'defaulttextinterpreter','latex')
set(groot,'defaultAxesTickLabelInterpreter','latex')
set(groot,'defaultLegendInterpreter','latex')
set(groot,'defaultLineLineWidth',1)
set(groot,'defaultFigureUnits','centimeters')
set(groot,'defaultFigurePosition',[4,4,17,10])
set(groot,'defaultAxesFontSize',12)
set(groot,'defaultFigureColor','white')

%%
close all

figure
hold on
grid minor

yyaxis left
plot(timeinput, input2, 'b')
xlim([-0.01 0.01])
ylim([-0.08 0])
ylabel('Voltage (V)')

yyaxis right
% plot(time,input,'--r')
% ylim([-0.5 4.5])
hold on;
% plot(time,peak_detection,'-r')
hold on;
plot(timeinput, ampsignal2, 'r')
ylim([-0.5 4.5])
xlim([-0.01 0.01])
xlabel('Time (s)')
ylabel('Voltage (V)')

title('Radar signal')
legend('$V_\mathrm{in}$', '$V_\mathrm{out}$')
exportgraphics(gcf,'radarsignal.eps','ContentType','vector')

%%

figure

yyaxis left
semilogx(freq,gain,'b')
ylabel('Gain (dB)')
ylim auto

hold on
grid minor

% phaserad = deg2rad(phase);

yyaxis right
semilogx(freq,unwrap(phase, 180),'r')
ylabel('Phase')
% ylim([-360 360])

xlabel('Frequency (Hz)')

title('Bode plot of Band Pass Filter')
% legend('$Gain$','$Phase$')
exportgraphics(gcf,'radarfilter.eps','ContentType','vector')

%%
close all
figure


subplot(2,2,1);
plot(400, 3.3, 'xb')
hold on
plot(dist,amp,'-b')
plot(dist2,amp2,'-r')
grid minor
xlabel("Distance (mm)")
ylabel('Amplitude (V)')
legend('Position of radar','Initial design', 'Improved dynamic range')
xlim([0 600])
legend('Location','northwest')
title('Amplitude against distance')

ax = gca;
ax.XAxis.Color = 'k';
ax.YAxis.Color = 'k';

subplot(2,2,2);
hold on
plot(180, 3.3, 'xb')
plot(angle,angamp,'-r')
plot(angle,angamp,'-r')
plot(angle,angamp,'-r')

xlabel("Angle ($^\circ$)")
ylabel('Distance amplitude (V)')
hold on
legend('Position of radar')
legend('Location','northwest')
grid minor
xlim([0 360])

ax = gca;
ax.XAxis.Color = 'k';
ax.YAxis.Color = 'k';

ylabel('Amplitude (V)')
title('Amplitude against angle')
exportgraphics(gcf,'radardist.eps','ContentType','vector')

%%


plot(bat_v, batt_i_fullydepleted, 'b')
hold on
grid minor
% plot(bat_v, batt_i_fullydepleted, 'b')
plot(bat_v, batt_i2, 'r')
% plot(bat_v, batt_i2, 'r')
plot(bat_v, batt_i3, 'k')
% plot(bat_v, batt_i3, 'k')
plot(bat_v, batt_i4, 'm')
% plot(bat_v, batt_i4, 'm')
xlim([4.5 5.2])

xlabel('Voltage (V)')
ylabel('Current (mA)')
title('Battery characterisation')
legend('Fully depleted', 'Almost fully charged', 'Fully charged, disconnected and reconnected','Fully charged')
legend('Location','northwest')
exportgraphics(gcf,'battcharac.eps','ContentType','vector')

%% 

figure
grid minor
hold on

plot(v1l/1000, i1l, 'g')
hold on
plot(v1, i1, 'b')
plot(vs, is,'r')
plot(vp, ip, 'k')
plot(vsp, isp, 'm')

xlabel('Voltage (V)')
ylabel('Current (mA)')
title('PV Cell characterisation')
legend('Single (low irradiance)', 'Single', 'Series', 'Parallel','2 Series 2 Parallel')
exportgraphics(gcf,'pvcharac.eps','ContentType','vector')

p1 = v1.*i1;
ps = vs.*is;
pp = vp.*ip;
psp = vsp.*isp;
p1l = v1l./1000.*i1l./1000;

figure
grid minor
hold on

plot(i1l/1000, p1l, 'g')
hold on
plot(i1, p1, 'b')
plot(is, ps,'r')
plot(ip, pp, 'k')
plot(isp, psp, 'm')

xlabel('Current (mA)')
ylabel('Power (W)')
% ylim([0 5])
title('Power against Current')
legend('Single (low irradiance)', 'Single', 'Series', 'Parallel','2 Series 2 Parallel')
legend('Location','southeast')
exportgraphics(gcf,'pvpv.eps','ContentType','vector')


figure
grid minor
hold on

plot(v1l/1000, p1l, 'g')
hold on
plot(v1, p1, 'b')
plot(vs, ps,'r')
plot(vp, pp, 'k')
plot(vsp, psp, 'm')

xlabel('Voltage (V)')
ylabel('Power (W)')
% ylim([0 5])
title('Power against Voltage')
legend('Single (low irradiance)', 'Single', 'Series', 'Parallel','2 Series 2 Parallel')
legend('Location','southeast')
exportgraphics(gcf,'pvpi.eps','ContentType','vector')
%%

figure
grid minor
hold on

plot(boostdutycycle, pboost/1000, 'b')
% plot(buckdutycycle, pbuck/1000, 'r')
plot(boostdutycycle, pboost/1000, 'xb')
% plot(buckdutycycle, pbuck/1000, 'xr')
xlim([0 0.7])

xlabel('Duty Cycle, $\delta$')
ylabel('Power (W)')
% legend('Boost', 'Buck')
title('Power against Duty Cycle for Boost NS')
exportgraphics(gcf,'boostbattcharac.eps','ContentType','vector')

%%

figure
grid minor
hold on

plot(mppttime/1000, pnopower/1000, '.b')
plot(mppttime(1:64)/1000, icpower/1000, '.r')

legend('Perturb \& Observe', 'Incremental Conductance')

xlabel('Time (s)')
ylabel('Power (W)')
title('Comparison of MPPT algorithm')
legend('Location','southeast')
exportgraphics(gcf,'mpptcomparison.eps','ContentType','vector')

%%

figure
grid minor
hold on

plot(bmpptv,bmppti, '.b')
plot(bbmpptv,bbmppti, '.r')
ylim([0 1100])
xlim([3.5 6])

legend('Boost', 'Boost-Buck')

xlabel('Voltage (V)')
ylabel('Current (mA)')
title('MPPT Tracking')
legend('Location','northwest')
exportgraphics(gcf,'mppttracking.eps','ContentType','vector')

%%

figure
grid minor
hold on

yyaxis left
plot(chargetime/200000, chargepower/1000, '.b')
ylabel('Power (W)')
ylim([0 4.5])

yyaxis right
plot(chargetime/200000, irradiance, '.r')
ylabel('Irradiance')
ylim([0 1050])

xlabel('Time (min)')

title('Irradiance level and Power against time')
exportgraphics(gcf,'chargeonebar.eps','ContentType','vector')

%%

figure
grid minor
hold on

yyaxis left
plot(bat_v, batt_i_fullydepleted, 'b')
ylabel('Current (mA)')

yyaxis right
plot(vp, pp, 'r')
ylabel('Power (W)')
xlabel('Voltage (V)')
ylim([0 5000])

title('Current and Power against Voltage')
exportgraphics(gcf,'battmpp.eps','ContentType','vector')


%%

figure
grid minor
hold on

plot(timecurrentlimit./60000, powerlimit/1000, '.b')
ylabel('Power (W)')
xlabel('Time (min)')
xlim([0 22])

title('Power against time (Power limit of BMS)')
exportgraphics(gcf,'powerlimit.eps','ContentType','vector')


%%

% figure
% hold on
% grid on
% 
% plot(freqMHz,20*log10(abs(s11)),'b')
% plot(freqMHz,20*log10(abs(s11model)),'--b')
% 
% plot(freqMHz,20*log10(abs(s21)),'r')
% plot(freqMHz,0*ones(npoints,1),'--r')
% 
% xlabel('Frequency (MHz)')
% ylabel('Amplitude (dB)')
% legend('$S_{11}$ measured','$S_{11}$ modelled','$S_{21}$ measured','$S_{21}$ modelled','Location','southeast')
% exportgraphics(gcf,'task1bE.eps','ContentType','vector')
% 
% figure
% hold on
% grid on
% 
% plot(freqMHz,real(s11),'b')
% plot(freqMHz,imag(s11),'r')
% 
% ylabel('Amplitude')
% xlabel('Frequency (MHz)')
% legend('$\Re(S_{11})$','$\Im(S_{11})$','Location','northwest')
% exportgraphics(gcf,'task1bE1.eps','ContentType','vector')
% 
% figure
% hold on
% grid on
% 
% plot(freqMHz,unwrap(angle(s11)),'b')
% plot(freqMHz,polyval(dfit,freq),'r')
% 
% xlabel('Frequency (MHz)')
% ylabel('Phase')
% legend('Measured $\mathrm{arg}(S_{11})$','$\mathrm{arg}(S_{11})\approx-2kd+\pi$','Location','northeast')
% exportgraphics(gcf,'task1bE2.eps','ContentType','vector')
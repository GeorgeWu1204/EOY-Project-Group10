load('controller_parameters.mat')

s = tf('s');

G0 = 0.5*K/(tau*s+1)*[R,R;R/L,-R/L];
G0.InputName = {'vr','vl'};
G0.OutputName = 'rphidot';

D = tunableGain('Decoupler',eye(2));
D.InputName = 'erphidot';
D.OutputName = {'d1','d2'};

PIvr = tunablePID('PIvr','pi');
PIvr.InputName = 'd1';
PIvr.OutputName = 'vr';

PIvl = tunablePID('PIvl','pi');
PIvl.InputName = 'd2';
PIvl.OutputName = 'vl';

sum1 = sumblk('erphidot = rphidotref - rphidot',2);

C0 = connect(PIvr,PIvl,D,sum1,{'rphidotref','rphidot'},{'vr','vl'});

[G0,C1,gam1,info1] = looptune(G0,C0,100);

showTunable(C1)

T1 = connect(G0,C1,'rphidotref','rphidot');
step(T1)

%%

G1 = 1/s*[1,0;0,1];
G1.InputName = 'rphidot';
G1.OutputName = 'rphi';

G2 = connect(T1,G1,'rphidotref','rphi');

PIr = tunablePID('PIr','pi');
PIr.InputName = 'erphi(1)';
PIr.OutputName = 'rphidotref(1)';

PIphi = tunablePID('PIphi','pi');
PIphi.InputName = 'erphi(2)';
PIphi.OutputName = 'rphidotref(2)';

sum2 = sumblk('erphi = rphiref - rphi',2);

C0 = connect(PIr,PIphi,sum2,{'rphiref','rphi'},'rphidotref');

[G2,C2,gam2,info2] = looptune(G2,C0,10);

showTunable(C2)

T2 = connect(G2,C2,'rphiref','rphi');
step(T2)

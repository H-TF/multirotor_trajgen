%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
% Parker Lusk
% 6 May 2019
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear, clc

% -------------------------------------------------------------------------
% Simulation Setup

% timing
Tf = 10;   % [s] how long is the simulation
Ts = 0.01; % [s] simulation / control period
N = Tf/Ts; %     number of iterations
tvec = linspace(0,Tf,N);

state.pos = zeros(3,1); % [m]     intertial-frame position
state.vel = zeros(3,1); % [m/s]   inertial-frame velocities
state.q = [1 0 0 0];    % (wxyz)  rotation of body w.r.t world
state.w = zeros(3,1);   % [rad/s] rate of body w.r.t world exprssd in body

% parameters
P.trajDrawPeriod = 0.1;
P.simDrawPeriod = 0.5;
P.Ts = Ts;
P.gravity = 9.80665; % [m/s/s]
P.mass = 1.4; % [kg]
P.J = diag([0.12 0.12 0.12]);
P.d = 0.3; % CG to prop (arm) length
P.c = 1; % prop drag for yaw
P.bodyDrag = 0.5;
% acceleration feedback PD controller
P.accel.Kp = diag([6.0 6.0 7.0]);
% P.accel.Kp = diag([1 1 1]);
P.accel.Kd = diag([4.5 4.5 5.0]);
% P.accel.Kd = diag([0 0 0]);
% moments feedback PD controller
P.att.Kp = diag([30 .10 0.3]);
% P.att.Kp = diag([0 0 0]);
P.att.Kd = diag([10 2 0.24]);
% P.att.Kd = diag([0.1 0.1 0.1]);
P.minRmag = 0.1;

% kinematic feasibility parameters
P.vmax = 4;
P.amax = 2;
P.jmax = 2;
P.smax = 2;

% -------------------------------------------------------------------------
% Trajectory Generation

% path: [x xd xdd xddd xdddd; y yd ... ; z zd ...]
path.s = [0 0 0 0 0; 0 0 0 0 0; 0 0 0 0 0];
path.wps = [];
path.wps(:,:,1) = [1.3 nan -0.7; 0 nan nan; 0.9 nan -9.8];
path.wps(:,:,2) = [1.5 0 0; 0 0 0; 1 0 -9.8];
% path.wps(:,:,3) = [1.7 nan 0.7; 0 nan nan; 0.9 nan -9.8];
% path.wps(:,:,1) = [1.4 nan -4; 0 nan nan; 1 nan nan];
% path.wps(:,:,2) = [1.6 nan 4; 0 nan nan; 1 nan nan];
path.e = [3 0 0 0 0; 0 0 0 0 0; 0 0 0 0 0];
path.T = [0 1.0 1.5 2.0 3.0];

path.wps(:,:,1) = [1.5 nan -0.7; 0 nan nan; 1 nan -9.8];
path.wps(:,:,2) = [4.5 nan 0.7; 0 nan nan; 1 nan -9.8];
path.e = [6.0 0 0 0 0; 0 0 0 0 0; 0 0 0 0 0];
path.T = [0 0.5 1.0 1.5];

% % path: [x xd xdd xddd xdddd; y yd ... ; z zd ...]
% path.s = [0 0 0 0 0; 0 0 0 0 0; 0 0 0 0 0];
% path.wps = [];
% path.wps(:,:,1) = [nan nan nan; nan nan nan; -0.5 nan nan];
% path.e = [6 0 0 0 0; 0 0 0 0 0; 0 0 0 0 0];
% path.T = [0 0.75 1.5]*2;

% path: [x xd xdd xddd xdddd; y yd ... ; z zd ...]
path.s = [0 0 0 0 0; 0 0 0 0 0; 0 0 0 0 0];
path.wps = [];
% path.wps(:,:,1) = [1.5 nan nan; 0 0 0; 0.5 nan nan];
path.wps(:,:,1) = [3 0 0; 0 0 0; 1 0 0];
% path.wps(:,:,1) = [3 nan nan; 0 nan nan; 0 nan nan];
path.e = [6 0 0 0 0; 0 0 0 0 0; 0 0 0 0 0];
path.T = [0 1 2];

[traj, ~] = trajgen(path, P);

fprintf('Total trajectory time: %f\n\n', traj.Tdurs(end));

% plot trajectory log
figure(2), clf; hold on;
plotTraj(traj, P);

% set up visualization
figure(1), clf; hold on;
hViz = viz(state, traj, [], [], P);

% -------------------------------------------------------------------------
% Main Simulation Loop

execute_path = true;

statelog = cell(N,1);
inputlog = cell(N,1);
goallog = cell(N,1);

for i = 1:N
    t = tvec(i);
    
    statelog{i} = state;
    
    goal = buildGoal(traj, i);
    cmd = controller(state, goal, t, P);
    
    hViz = viz(state, [], cmd, hViz, P);
    
    if execute_path == true
        state = dynamics(state, cmd.u, Ts, P);
        if mod(i,P.simDrawPeriod/P.Ts) == 0, drawnow; end
    end
    
    inputlog{i} = cmd;
    goallog{i} = goal;
    
    % check for runaways
    if any(abs(state.pos)>100)
        fprintf('\n**Runaway detected**\n\n');
        break;
    end
end

% Plot state log
figure(3), clf; hold on;
plotState(statelog, inputlog, goallog, tvec, P);

% =========================================================================
% Helpers
% =========================================================================

function goal = buildGoal(traj, i)
%BUILDGOAL Builds a goal struct using the ith step of a trajectory

% If we are still simulating, but have no more trajectory, just send the
% last position and hover there.
if i > size(traj.p,1), i = size(traj.p,1); end

goal.pos = traj.p(i,:)';
goal.vel = traj.v(i,:)';
goal.accel = traj.a(i,:)';
goal.jerk = traj.j(i,:)';

% goal.pos = [0.5 0 0]';
% goal.vel = [0 0 0]';
% goal.accel = [0 0 0]';
% goal.jerk = [0 0 0]';

end

function plotTraj(traj, P)
subplot(411); plot(traj.p); grid on; ylabel('Position'); legend('x','y','z');
title('Desired Trajectory');
subplot(412); plot(traj.v); grid on; ylabel('Velocity');
subplot(413); plot(traj.a); grid on; ylabel('Acceleration');
subplot(414); plot(traj.j); grid on; ylabel('Jerk');
xlabel('Time [s]');
end

function plotState(statelog, inputlog, goallog, tvec, P)

states = [statelog{:}];
p = [states.pos]';
v = [states.vel]';
q = reshape([states.q], 4, size(p,1))';
w = [states.w]' * 180/pi;

inputs = [inputlog{:}];
u = [inputs.u]';
Fi = [inputs.Fi]';
qdes = reshape([inputs.qdes], 4, size(p,1))';
qe = reshape([inputs.qe], 4, size(p,1))';
wdes = [inputs.wdes]' * 180/pi;
afb = [inputs.accel_fb]';
jfb = [inputs.jerk_fb]';

goals = [goallog{:}];
pdes = [goals.pos]';
vdes = [goals.vel]';

% quaternion to RPY for plotting
RPY = quat2eul(q,'ZYX') * 180/pi;
RPYdes = quat2eul(qdes,'ZYX') * 180/pi;
RPYerr = quat2eul(qe,'ZYX') * 180/pi;

% in case of early terminations
tvec = tvec(1:length(p));

% color order: make the desired and actual traces the same color
co = get(gca, 'ColorOrder');
set(groot, 'defaultAxesColorOrder', [co(1:3,:); co(1:3,:)]);

n = 8; i = 1;
subplot(n,1,i); i = i+1;
plot(tvec,p); grid on; ylabel('Position'); hold on;
plot(tvec,pdes,'--');
title('State Log'); legend('x','y','z');

subplot(n,1,i); i = i+1;
plot(tvec,v); grid on; ylabel('Velocity'); hold on;
plot(tvec,vdes,'--');

% subplot(n,1,i); i = i+1;
% plot(tvec,q(:,2:4)); grid on; ylabel('Quaternion'); hold on;
% plot(tvec,qdes(:,2:4),'--');

subplot(n,1,i); i = i+1;
plot(tvec,RPY); grid on; ylabel('Euler RPY'); hold on;
plot(tvec,RPYdes,'--');

subplot(n,1,i); i = i+1;
plot(tvec,sign(qe(:,1)).*qe(:,2:4)); grid on; ylabel('Quat Error');

% subplot(n,1,i); i = i+1;
% plot(tvec,RPYerr); grid on; ylabel('RPY Error');

subplot(n,1,i); i = i+1;
plot(tvec,w); grid on; ylabel('Body Rates'); hold on;
plot(tvec,wdes,'--');

subplot(n,1,i); i = i+1;
plot(tvec,u(:,1)); grid on; ylabel('Thrust');

subplot(n,1,i); i = i+1;
plot(tvec,u(:,2:4)); grid on; ylabel('Moments');

% subplot(n,1,i); i = i+1;
% plot(tvec,afb); grid on; ylabel('Accel Feedback');

subplot(n,1,i); i = i+1;
plot(tvec,jfb); grid on; ylabel('Jerk Feedback');

xlabel('Time [s]');

end
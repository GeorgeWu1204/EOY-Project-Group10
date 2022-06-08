class roverdrive {

    public:

        roverdrive();

        int state = 0;  // for state machine, not fully implemented yet

        float x = 0;    // rover global coordinates
        float y = 0;
        float theta = 0;

        float r = 0;    // local coordinates, frequently reset
        float phi = 0;
        float phideg = 0;

        float dx;
        float dy;
        float dr;
        float dphi;

        float vel;
        float omega;

        void start();   // to call in setup

        void measure(); // sample optical flow sensor measurements

        void rotate(float omega, bool stop);    // rotation at fixed rate until stop = true

        void rotateBack();

        void translateToTarget(float rtarget);  // move to target radial distance
        void rotateToTarget(float phitarget, float omega);   // rotate to target angle

        void twopoint(float x, float y);    // DO NOT USE, unstable at low velocities

        void motorA(float v);   // move motors individually
        void motorB(float v);

        void brake();   // stop both motors

        int squal;  // optical flow sensor surface quality

        void fixedvel(float velref);    // DO NOT USE, unstable at low velocities

    private:

        int convTwosComp(int b);

        void mousecam_reset();
        void mousecam_init();
        void mousecam_write_reg(int reg, int val);
        int mousecam_read_reg(int reg);
        void mousecam_read_motion();

        int motion;
        int squalreg;
        int dxreg;
        int dyreg;
        int shutter;
        int max_pix;

        float scale = 0.2;

        float pid(float input, float kp, float ki, bool limit, float& e1, float& u1);

};
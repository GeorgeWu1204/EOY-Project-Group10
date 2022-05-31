class roverdrive {

    public:

        roverdrive();

        int state = 0; // 0 = idle, 1 = rotating, 2 = moving, 3 = awaiting

        float x = 0;
        float y = 0;
        float r = 0;
        float phi = 0;

        float dx;
        float dy;
        float dr;
        float dphi;

        float vel;
        float omega;

        void start();

        void measure();

        void translate(float rtarget);
        void rotate(float phitarget);

        void twopoint(float x, float y);

        void motorA(float v);
        void motorB(float v);

        void brake();

        int squal;

        void fixedvel(float velref);

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
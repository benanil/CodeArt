
namespace CodeArt
{
    public static class Time
    {
        public static float time;
        public static float DeltaTime;

        public static void Tick(float dt)
        {
            DeltaTime = dt;
            time += dt;
        }
    }
}

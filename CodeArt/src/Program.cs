using OpenTK.Windowing.Desktop;

namespace CodeArt
{
    class Program
    {
        static void Main(string[] args)
        {
            var windowSettings = new GameWindowSettings();
            windowSettings.UpdateFrequency = 60;
            windowSettings.RenderFrequency = 60;

            var nativeWindowSettings = new NativeWindowSettings() 
            {
                Title = "Code Art",
                Size = new OpenTK.Mathematics.Vector2i(800, 600),
                NumberOfSamples = 8
            };
            
            using CodeArt mainLoop = new CodeArt(windowSettings, nativeWindowSettings);
            
            mainLoop.Run();
        }
    }
}

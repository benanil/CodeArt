using OpenTK.Windowing.Desktop;

namespace CodeArt
{
    class Program
    {
        static void Main(string[] args)
        {
            var windowSettings = new GameWindowSettings();
            
            var nativeWindowSettings = new NativeWindowSettings() 
            {
                Title = "Code Art",
                Size = new OpenTK.Mathematics.Vector2i(800, 600), 
            };
            
            using CodeArt mainLoop = new CodeArt(windowSettings, nativeWindowSettings);
            
            mainLoop.Run();
        }
    }
}

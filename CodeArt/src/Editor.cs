
using Coroutine;
using ImGuiNET;
using System;
using System.Collections.Generic;

namespace CodeArt
{
    public class Editor
    {
        static readonly float[] fpsHistory = new float[11];
        public static event Action OnWindow = Draw;

        public static void Construct()
        {
            for (byte i = 0; i < fpsHistory.Length; i++)
            {
                fpsHistory[i] = 1 / Time.DeltaTime;
            }
            CoroutineHandler.Start(OneSec());
        }

        private static bool Open = true;

        public static void ImguiWindow()
        {
            if (ImGui.Begin("main",ref Open))
            {
                OnWindow();
            }
            ImGui.End();
        }

        static void Draw()
        { 
            ImGui.PlotHistogram($"fps: {fpsHistory[^1]}", ref fpsHistory[0], fpsHistory.Length, 0, " ", 0, CodeArt.MaxFps);
        }

        static IEnumerator<Wait> OneSec()
        {
            while (true)
            {
                for (var i = 0; i < fpsHistory.Length - 1; i++)
                {
                    fpsHistory[i] = fpsHistory[i + 1];
                }
                fpsHistory[^1] = 1 / Time.DeltaTime;
                yield return new Wait(1);
            }
        }
    }
}

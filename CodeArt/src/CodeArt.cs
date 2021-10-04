using System;
using OpenTK.Windowing.GraphicsLibraryFramework;
using OpenTK.Windowing.Common;
using OpenTK.Windowing.Desktop;
using OpenTK.Graphics.OpenGL4;
using OpenTK.Mathematics;
using System.Runtime.InteropServices;
using Dear_ImGui_Sample;
using Coroutine;
using ImGuiNET;

namespace CodeArt
{
    public class CodeArt : GameWindow
    {
        public CodeArt(GameWindowSettings gameWindowSettings, NativeWindowSettings nativeWindowSettings) : base(gameWindowSettings, nativeWindowSettings){}

        public static CodeArt instance;

        private static readonly float[] vertices =
        {
             1.0f,  1.0f, 1.0f, 1.0f,  // top right
             1.0f, -1.0f, 1.0f, 0.0f,  // bottom right
            -1.0f, -1.0f, 0.0f, 0.0f,  // bottom left
            -1.0f,  1.0f, 0.0f, 1.0f   // top left
        };

        [StructLayout(LayoutKind.Sequential)]
        private struct Data
        {
            public float time;
            public Vector2 screenSize;
            public float scale;
        }

        private int vbo;
        private int vao;
        private int dataUBO;

        private Shader shader;
        private ComputeShader mainCompute;
        private Data data;
        private ImGuiController ImguiController;

        protected unsafe override void OnLoad()
        {
            instance = this;
            ImguiController = new ImGuiController(ClientSize.X, ClientSize.Y);
            Editor.Construct();
            Editor.OnWindow += OnWindow;
            ImGuiController.DarkTheme();

            base.OnLoad();

            GL.ClearColor(0.2f, 0.3f, 0.3f, 1.0f);

            vbo = GL.GenBuffer();

            GL.BindBuffer(BufferTarget.ArrayBuffer, vbo);
            GL.BufferData(BufferTarget.ArrayBuffer, vertices.Length * sizeof(float), vertices, BufferUsageHint.StaticDraw);

            vao = GL.GenVertexArray();
            GL.BindVertexArray(vao);

            GL.VertexAttribPointer(0, 4, VertexAttribPointerType.Float, false, 4 * sizeof(float), 0);

            GL.EnableVertexAttribArray(0);

            shader = new Shader(Helper.AssetsPath + "Shaders/Screen.vert", Helper.AssetsPath + "Shaders/Screen.frag");
            mainCompute = new ComputeShader(Helper.AssetsPath + "Shaders/Main.glsl", 1440, 900);
            
            data = new Data
            {
                screenSize = new Vector2(1440, 900),
                scale = 8
            };

            dataUBO = GL.GenBuffer();
            GL.BindBuffer(BufferTarget.UniformBuffer, dataUBO);
            GL.BufferData(BufferTarget.UniformBuffer, sizeof(float) * 4, IntPtr.Zero, BufferUsageHint.StaticDraw);
            
            int index = GL.GetUniformBlockIndex(mainCompute.programId, "DataBlock");
            GL.UniformBlockBinding(mainCompute.programId, index, 0);
            
            shader.Use();
        }

        private void OnWindow()
        {
            ImGui.DragFloat("scale", ref data.scale);
        }

        protected unsafe override void OnRenderFrame(FrameEventArgs e)
        {
            base.OnRenderFrame(e);

            GL.Clear(ClearBufferMask.ColorBufferBit | ClearBufferMask.DepthBufferBit | ClearBufferMask.StencilBufferBit);

            mainCompute.Use();
            {
                data.time = Time.time;
                GL.BindBuffer(BufferTarget.UniformBuffer, dataUBO);
                GL.BindBufferRange(BufferRangeTarget.UniformBuffer, 0, dataUBO, IntPtr.Zero, sizeof(float) * 4);
                GL.BufferSubData(BufferTarget.UniformBuffer, IntPtr.Zero, sizeof(float) * 4, ref data);
                mainCompute.Dispatch();
            }

            shader.Use();
            GL.ActiveTexture(TextureUnit.Texture0);
            GL.BindTexture(TextureTarget.Texture2D, mainCompute.TexId);
            
            GL.BindVertexArray(vao);
            GL.DrawArrays(PrimitiveType.TriangleFan, 0, 4);

            Editor.ImguiWindow();

            ImguiController.Render();

            GL.Flush();
            SwapBuffers();
        }

        public static int MaxFps = 2000;
        
        bool vsyncOpen;

        protected override void OnTextInput(TextInputEventArgs e)
        {
            if (e.AsString[0] == 'v') {
                vsyncOpen = !vsyncOpen;
                VSync = vsyncOpen ? VSyncMode.On : VSyncMode.Off;
                MaxFps = vsyncOpen ? 70 : 2000;
            } 

            base.OnTextInput(e);
            ImguiController.PressChar(e.AsString[0]);
        }

        protected override void OnMouseWheel(MouseWheelEventArgs e)
        {
            ImguiController.MouseScroll(e.Offset);
            base.OnMouseWheel(e);
        }

        protected override void OnUpdateFrame(FrameEventArgs e)
        {
            base.OnUpdateFrame(e);

            Time.Tick((float)e.Time);
            ImguiController.Update(this, (float)e.Time);
            CoroutineHandler.Tick(e.Time);

            if (KeyboardState.IsKeyDown(Keys.Escape))
            {
                Close();
            }
        }

        protected override void OnResize(ResizeEventArgs e)
        {
            base.OnResize(e);
            data.screenSize = e.Size;
            mainCompute.Invalidate(e.Size.X, e.Size.Y);
            GL.Viewport(0, 0, e.Size.X, e.Size.Y);
            ImguiController?.WindowResized(e.Width, e.Height);
        }
    }
}

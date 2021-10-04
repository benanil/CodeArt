using OpenTK.Graphics.OpenGL4;
using System;
using System.IO;

namespace CodeArt
{
    public class ComputeShader
    {
        public int TexId, programId;
        public int width, height;
        static readonly int[] workGroupCount = new int[3];

        static ComputeShader()
        {
            GL.GetInteger((GetIndexedPName)All.MaxComputeWorkGroupCount, 0, out workGroupCount[0]);
            GL.GetInteger((GetIndexedPName)All.MaxComputeWorkGroupCount, 1, out workGroupCount[1]);
            GL.GetInteger((GetIndexedPName)All.MaxComputeWorkGroupCount, 2, out workGroupCount[2]);
            Debug.LogWarning("GPU Work Group Count 0" + workGroupCount[0]);
            Debug.LogWarning("GPU Work Group Count 1" + workGroupCount[1]);
            Debug.LogWarning("GPU Work Group Count 2" + workGroupCount[2]);
        }

        public ComputeShader(string path, in int width, in int height)
        {
            Invalidate(width, height);

            // generate and link compute shader shader
            int compute = GL.CreateShader(ShaderType.ComputeShader);
            GL.ShaderSource(compute, File.ReadAllText(path));
            GL.CompileShader(compute);

            GL.GetShader(compute, ShaderParameter.CompileStatus, out int log);

            if (log == 0)
            {
                GL.GetShaderInfoLog(compute, out string info);
                Debug.LogError(info);
                throw new Exception("compute shader compilation failed");
            }

            programId = GL.CreateProgram();
            GL.AttachShader(programId, compute);
            GL.LinkProgram(programId);

            GL.DeleteShader(compute);
            GL.DetachShader(programId, compute);
        }

        public void Invalidate(in int width, in int height)
        {
            this.width = width; this.height = height;
            GL.DeleteTexture(TexId);

            TexId = GL.GenTexture();
            GL.BindTexture(TextureTarget.Texture2D, TexId);
            GL.TexParameter(TextureTarget.Texture2D, TextureParameterName.TextureMinFilter, (int)TextureMinFilter.Nearest);
            GL.TexParameter(TextureTarget.Texture2D, TextureParameterName.TextureMagFilter, (int)TextureMagFilter.Nearest);
            
            GL.TexImage2D(TextureTarget.Texture2D, 0, PixelInternalFormat.Rgba32f, width, height, 0, PixelFormat.Rgba, PixelType.Float, IntPtr.Zero);
        }

        public void Dispatch()
        {
            GL.BindImageTexture(0, TexId, 0, false, 0, TextureAccess.WriteOnly, SizedInternalFormat.Rgba32f);
            GL.DispatchCompute(width / 8, height / 8, 1);
            GL.MemoryBarrier(MemoryBarrierFlags.ShaderImageAccessBarrierBit);
        }

        /// <summary> use compute and update uniforms </summary>
        public void Use()
        {
            GL.UseProgram(programId);
        }
    }
}

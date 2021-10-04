#version 440

layout (location = 0) in vec4 vertex;

out vec2 texCoord;
 
void main()
{
    texCoord = vertex.zw;
    gl_Position = vec4(vertex.xy, 0, 1);
}

#version 440
out vec4 outColor;

in vec2 texCoord;
uniform sampler2D texture0;

void main()
{
	outColor = texture(texture0, texCoord);
}
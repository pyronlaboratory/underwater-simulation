struct PixelShaderInput
{
	float4 pos : SV_POSITION;
	float3 color : COLOR0;
};

float4 main(PixelShaderInput input) : SV_TARGET
{
    
	float4 color = float4(input.color, 1.0f);
	return color;
}

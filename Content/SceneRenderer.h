﻿#pragma once

#include "..\Common\DeviceResources.h"
#include "ShaderStructures.h"
#include "..\Common\StepTimer.h"

namespace _202219807_ACW_700119_D3D11_UWP_APP
{
	// This sample renderer instantiates a basic rendering pipeline.
	class SceneRenderer
	{
	public:
		SceneRenderer(const std::shared_ptr<DX::DeviceResources>& deviceResources);
		void CreateDeviceDependentResources();
		void CreateWindowSizeDependentResources();
		void ReleaseDeviceDependentResources();
		void Update(DX::StepTimer const& timer);
		void Render(DX::StepTimer const& timer);
		
		void StartTracking();
		void TrackingUpdate(float positionX);
		void StopTracking();
		bool IsTracking() { return m_tracking; }


	private:
		void Rotate(float radians);

	private:
		// Cached pointer to device resources.
		std::shared_ptr<DX::DeviceResources>		    m_deviceResources;
													    
		// Direct3D resources for cube geometry.	    
		Microsoft::WRL::ComPtr<ID3D11InputLayout>	    m_inputLayout;
		Microsoft::WRL::ComPtr<ID3D11Buffer>		    m_vertexBuffer;
		Microsoft::WRL::ComPtr<ID3D11Buffer>		    m_indexBuffer;
		Microsoft::WRL::ComPtr<ID3D11VertexShader>	    m_vertexShader01;
		Microsoft::WRL::ComPtr<ID3D11PixelShader>	    m_pixelShader01;
		Microsoft::WRL::ComPtr<ID3D11VertexShader>	    m_vertexShader02;
		Microsoft::WRL::ComPtr<ID3D11PixelShader>	    m_pixelShader02;
		Microsoft::WRL::ComPtr<ID3D11Buffer>		    m_constantBuffer;
		Microsoft::WRL::ComPtr<ID3D11RasterizerState>   m_RasterizerState;

		// System resources for cube geometry.
		ModelViewProjectionConstantBuffer				m_constantBufferData;
		uint32											m_indexCount;

		// Variables used with the rendering loop.
		bool											m_loadingComplete;
		float											m_degreesPerSecond;
		bool											m_tracking;
	};
}
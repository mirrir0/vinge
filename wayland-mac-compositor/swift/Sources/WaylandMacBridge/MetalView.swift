import Metal
import MetalKit
import AppKit

// C interface for Zig to call
@_cdecl("create_metal_window")
public func createMetalWindow() -> UnsafeMutableRawPointer? {
    let window = WaylandWindow()
    return Unmanaged.passRetained(window).toOpaque()
}

@_cdecl("draw_surface")
public func drawSurface(_ windowPtr: UnsafeMutableRawPointer, 
                       _ buffer: UnsafeRawPointer,
                       _ width: Int32,
                       _ height: Int32) {
    let window = Unmanaged<WaylandWindow>.fromOpaque(windowPtr).takeUnretainedValue()
    window.drawBuffer(buffer: buffer, width: Int(width), height: Int(height))
}

@_cdecl("destroy_metal_window")
public func destroyMetalWindow(_ windowPtr: UnsafeMutableRawPointer) {
    Unmanaged<WaylandWindow>.fromOpaque(windowPtr).release()
}

class WaylandWindow: NSObject {
    private var window: NSWindow!
    private var metalView: MTKView!
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var currentTexture: MTLTexture?
    
    override init() {
        super.init()
        
        // Initialize Metal
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Could not create command queue")
        }
        self.commandQueue = commandQueue
        
        // Create window
        let rect = NSRect(x: 0, y: 0, width: 800, height: 600)
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // Create Metal view
        metalView = MTKView(frame: rect, device: device)
        metalView.delegate = self
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        window.contentView = metalView
        window.title = "Wayland Compositor"
        window.makeKeyAndOrderFront(nil)
        
        // Ensure app is active
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func drawBuffer(buffer: UnsafeRawPointer, width: Int, height: Int) {
        // Create texture descriptor
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .renderTarget]
        
        // Create texture
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            print("Failed to create texture")
            return
        }
        
        // Copy buffer data to texture
        let region = MTLRegion(origin: MTLOrigin(), size: MTLSize(width: width, height: height, depth: 1))
        texture.replace(region: region, mipmapLevel: 0, withBytes: buffer, bytesPerRow: width * 4)
        
        currentTexture = texture
        metalView.draw()
    }
}

extension WaylandWindow: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle resize
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let currentTexture = currentTexture else {
            return
        }
        
        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Set up render pipeline
        let library = try? device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        
        let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        if let pipelineState = pipelineState {
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setFragmentTexture(currentTexture, index: 0)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// Metal shaders
let shaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    const float2 vertices[] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(1, -1), float2(1, 1), float2(-1, 1)
    };
    
    const float2 texCoords[] = {
        float2(0, 1), float2(1, 1), float2(0, 0),
        float2(1, 1), float2(1, 0), float2(0, 0)
    };
    
    VertexOut out;
    out.position = float4(vertices[vertexID], 0, 1);
    out.texCoord = texCoords[vertexID];
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                             texture2d<float> texture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    return texture.sample(textureSampler, in.texCoord);
}
"""
package h3d.impl;
import h3d.impl.Driver;

#if hlmetal
@:allow(h3d.impl.FuncAndLib)
@:structInit
class BufferAndSize {
	var buffer: metal.MTLBuffer;
	var size: Int;
}

@:structInit
class FuncAndLib {
	var func: metal.MTLFunction;
	var lib: metal.MTLLibrary;

	// buffers
	var globals : BufferAndSize;
	var params : BufferAndSize;
	var textures: haxe.ds.Vector<metal.MTLTexture>;
	var buffers: haxe.ds.Vector<metal.MTLBuffer>;

	public function uploadBuffer(driver: MetalDriver, buffers: h3d.shader.Buffers.ShaderBuffers, which: h3d.shader.Buffers.BufferKind)
	{
		trace('Uploading buffer ${which} for ${func}');

		switch( which ) {
			case Globals:
				var data = hl.Bytes.getArray(buffers.globals.toData());
				var byteSize = this.globals.size << 4;

				trace('contentsMemcpy for globals');
				this.globals.buffer.contentsMemcpy(
					data,
					0,
					byteSize);
			case Params:
				var data = hl.Bytes.getArray(buffers.params.toData());
				var byteSize = this.params.size << 4;

				trace('contentsMemcpy for params');
				this.params.buffer.contentsMemcpy(
					data,
					0,
					byteSize);
			case Buffers:
				// var data = hl.Bytes.getArray(buffers.params.toData());
				// var byteSize = this.params.size << 4;
				if (buffers.buffers != null) {
					var bcount = buffers.buffers.length;
					for( i in 0...bcount ) {
						throw ('Uploading buffer $i');
					}
				}

				// trace('contentsMemcpy for params');
				// this.params.buffer.contentsMemcpy(
				// 	data,
				// 	0,
				// 	byteSize);
			case Textures:
				var tcount = buffers.tex.length;
				trace('Uploading $tcount textures');
				if (tcount != this.textures.length) {
					throw 'Trying to allocate $tcount textures but shader expects ${this.textures.length}';
				}
				for( i in 0...tcount ) {
					var heapsTex = buffers.tex[i];
					var metalTex = driver.allocTexture(heapsTex);
					trace('Allocated texture $metalTex');
					this.textures[i] = metalTex;
				}
		}
	}
}

private class CompiledShader {
	public var vertex(default, null) : FuncAndLib;
	public var fragment(default, null) : FuncAndLib;
	var state : metal.MTLRenderPipelineState;

	public function new(
		vertex: FuncAndLib,
		fragment: FuncAndLib,
		state : metal.MTLRenderPipelineState ) {

		this.vertex = vertex;
		this.fragment = fragment;
		this.state = state;
	}
}

class MetalDriver extends Driver {

	var debug : Bool;

	var frame : Int;

	var bufferWidth : Int;
	var bufferHeight : Int;

	var shaders : Map<Int,CompiledShader>;
	var currentShader : CompiledShader;

	// Metal (global)
	var device: metal.MTLDevice;
	var renderPassDescriptor: metal.MTLRenderPassDescriptor;
	var window: metal.Window;
	var driver: metal.Driver;
	var commandQueue : metal.MTLCommandQueue;

	// Metal (frame)
	var frameCommandBuffer: metal.MTLCommandBuffer;
	var frameCurrentDrawable: metal.CAMetalDrawable;
	var frameRenderEncoder: metal.MTLRenderCommandEncoder;

	// public var backBufferFormat : metal.Format = R8G8B8A8_UNORM;

	public function new(window: metal.Window) {
		this.window = window;

		this.driver = new metal.Driver(window);

		//
		this.device = this.driver.device;
		this.commandQueue = this.device.newCommandQueue();

		this.renderPassDescriptor = new metal.MTLRenderPassDescriptor();

		var descriptor: metal.MTLRenderPassColorAttachmentDescriptor = {
			loadAction: MTLLoadActionClear,
			storeAction: MTLStoreActionStore,
			texture: null,
			clearColor: {
				red: 0,
				green: 1,
				blue: 1,
				alpha: 1
			}
		};
		this.renderPassDescriptor.colorAttachments = new hl.NativeArray<metal.MTLRenderPassColorAttachmentDescriptor>(1);
		this.renderPassDescriptor.colorAttachments[0] = descriptor;

		reset();
	}

	function reset() {
		this.shaders = new Map();
	}

	override function logImpl(str:String) {
		#if sys
		Sys.println(str);
		#else
		trace(str);
		#end
	}

	override function present() {
		// trace("[MetalDriver#present]");
		@:privateAccess hxd.Window.inst.window.present();
	}

	override function init( onCreate : Bool -> Void, forceSoftware = false ) {
		onCreate(false);
	}

	override public function hasFeature( f : Feature ): Bool {
		// https://developer.apple.com/documentation/metal/mtldevice/detecting_gpu_features_and_metal_software_versions?language=objc
		trace('Querying for feature $f');
		return switch( f ) {
			case HardwareAccelerated, AllocDepthBuffer, BottomLeftCoords:
				true;
			case BottomLeftCoords:
				false;
			default:
				throw 'Feature check not implemented for $f';
		};
	}

	override public function setRenderFlag( r : RenderFlag, value : Int ) {
		throw "Not implemented";
	}

	override public function isSupportedFormat( fmt : h3d.mat.Data.TextureFormat ): Bool {
		return switch( fmt ) {
		case R16F: true;
		default:
			trace('isSupportedFormat? $fmt');
			throw "Not implemented";
		}
	}

	override function isDisposed(): Bool {
		return false;
	}

	override public function dispose() {
		throw "Not implemented";
	}

	override public function begin( frame : Int ) {
		this.frame = frame;

		this.frameCommandBuffer = this.commandQueue.commandBuffer();
		this.frameCurrentDrawable = this.driver.getCurrentDrawable();

		trace('Got frame command buffer ${this.frameCommandBuffer}');
		trace('Got frame drawable ${this.frameCurrentDrawable}');
		if (this.frameCurrentDrawable == null) {
			trace('No drawable, skip rendering this frame');
			this.frameCommandBuffer = null;
			return;
		}

		this.renderPassDescriptor.colorAttachments[0].texture = this.frameCurrentDrawable.getTexture();

		// metal.MTLCommandBuffer.nativeTest(exts);

		this.frameRenderEncoder = this.frameCommandBuffer.renderCommandEncoderWithDescriptor(this.renderPassDescriptor);
		throw "Sup?";
	}

	override public function generateMipMaps( texture : h3d.mat.Texture ) {
		throw "Mipmaps auto generation is not supported on this platform";
	}

	override public function getNativeShaderCode( shader : hxsl.RuntimeShader ) : String {
		throw "Not implemented";
	}

	override public function clear( ?color : h3d.Vector, ?depth : Float, ?stencil : Int ) {
		if (color != null) {
			trace('Clearing ${color.r} ${color.g} ${color.b} ${color.a}');
		}
		trace('IGNORING SETTING CLEAR COLOR');
	}

	override public function captureRenderBuffer( pixels : hxd.Pixels ) {
		throw "Not implemented";
	}

	override public function capturePixels( tex : h3d.mat.Texture, layer : Int, mipLevel : Int, ?region : h2d.col.IBounds ) : hxd.Pixels {
		throw "Can't capture pixels on this platform";
	}

	override public function getDriverName( details : Bool ) {
		return "MetalDriver";
	}

	override public function resize( width : Int, height : Int ) {
		bufferWidth = width;
		bufferHeight = height;
		driver.resizeViewport(width, height);
	}

	override public function selectShader( shader : hxsl.RuntimeShader ): Bool {
		var s = shaders.get(shader.id);
		if( s == null ) {
			trace('Compiling ${shader.vertex.data.name}');
			var vertex = compileShader(shader.vertex);
			var fragment = compileShader(shader.fragment);

			var stateDesc : metal.MTLRenderPipelineDescriptor = {
				vertexFunction: @:privateAccess vertex.func,
				fragmentFunction: @:privateAccess fragment.func
			};

			var state = driver.device.newRenderPipelineStateWithDescriptor(stateDesc);

			s = new CompiledShader(vertex, fragment, state);
			shaders.set(shader.id, s);
		}

		if (currentShader == s) return false;
		setShader(s);
		return true;
	}

	function setShader( s : CompiledShader ) {
		currentShader = s;

		// MTLRenderPipelineDescriptor pipelineDesc = [MTLRenderPipelineDescriptor new];
        // pipelineDesc.sampleCount = self.sampleCount;
        // pipelineDesc.vertexFunction = vertFunc;
        // pipelineDesc.fragmentFunction = fragFunc;
        // pipelineDesc.vertexDescriptor = vertDesc;
        // pipelineDesc.colorAttachments[0].pixelFormat = self.metalView.colorPixelFormat;
        // pipelineDesc.depthAttachmentPixelFormat = self.metalView.depthStencilPixelFormat;
        // pipelineDesc.stencilAttachmentPixelFormat = self.metalView.depthStencilPixelFormat;

        // _pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];

		// throw "Not impl";
	}

	function compileShader( shader : hxsl.RuntimeShader.RuntimeShaderData, compileOnly = false ): FuncAndLib {
		var h = new hxsl.MetalOut();
		var dxx = new hxsl.HlslOut();
		var g = new hxsl.GlslOut();

		if( shader.code == null ){
			trace('HlslOut: ${dxx.run(shader.data)}');
			trace('GlslOut: ${g.run(shader.data)}');
			shader.code = h.run(shader.data);
			trace('MetalOut: ${shader.code}');
			shader.data.funs = null;
		}

		var lib: metal.MTLLibrary = driver.device.newLibraryFromSource(shader.code);
		var func: metal.MTLFunction = lib.newFunction(shader.vertex ? "vert_main" : "frag_main");
		trace('Got $func from $lib');

		// gl.uniform4fv(
		// 	s.globals,
		// 	streamData(
		// 		hl.Bytes.getArray(
		// 			buf.globals.toData()),
		// 		0,
		// 		s.shader.globalsSize * 16
		// 	),
		// 	0,
		// 	s.shader.globalsSize * 4);
		trace('Creating globals buffer with: ${shader.globalsSize}');
		var globalBuf = device.newBufferWithLengthOptions(
				shader.globalsSize * 4,
				metal.MTLResourceOptions.MTLResourceStorageModeShared);

		trace('Creating param buffer with: ${shader.paramsSize}');
		var paramBuf = device.newBufferWithLengthOptions(
				shader.paramsSize * 4,
				metal.MTLResourceOptions.MTLResourceStorageModeShared);

		trace('Creating textures with ${shader.texturesCount} textures');
		var textures = new haxe.ds.Vector<metal.MTLTexture>(shader.texturesCount);

		trace('Creating ${shader.bufferCount} buffers');
		var buffers = new haxe.ds.Vector<metal.MTLBuffer>(shader.bufferCount);

		return {
			func: func,
			lib: lib,
			globals: {buffer: globalBuf, size: shader.globalsSize},
			params: {buffer: paramBuf, size: shader.paramsSize},
			buffers: buffers,
			textures: textures
		};
		// var bytes = getBinaryPayload(shader.code);
		// if( bytes == null ) {
		// 	bytes = try dx.Driver.compileShader(shader.code, "", "main", (shader.vertex?"vs_":"ps_") + shaderVersion, OptimizationLevel3) catch( err : String ) {
		// 		err = ~/^\(([0-9]+),([0-9]+)-([0-9]+)\)/gm.map(err, function(r) {
		// 			var line = Std.parseInt(r.matched(1));
		// 			var char = Std.parseInt(r.matched(2));
		// 			var end = Std.parseInt(r.matched(3));
		// 			return "\n<< " + shader.code.split("\n")[line - 1].substr(char-1,end - char + 1) +" >>";
		// 		});
		// 		throw "Shader compilation error " + err + "\n\nin\n\n" + shader.code;
		// 	}
		// 	shader.code += addBinaryPayload(bytes);
		// }
		// if( compileOnly )
		// 	return { s : null, bytes : bytes };
		// var s = shader.vertex ? Driver.createVertexShader(bytes) : Driver.createPixelShader(bytes);
		// if( s == null ) {
		// 	if( hasDeviceError ) return null;
		// 	throw "Failed to create shader\n" + shader.code;
		// }

		// var ctx = new ShaderContext(s);
		// ctx.globalsSize = shader.globalsSize;
		// ctx.paramsSize = shader.paramsSize;
		// ctx.paramsContent = new hl.Bytes(shader.paramsSize * 16);
		// ctx.paramsContent.fill(0, shader.paramsSize * 16, 0xDD);
		// ctx.texturesCount = shader.texturesCount;
		// ctx.bufferCount = shader.bufferCount;
		// ctx.globals = dx.Driver.createBuffer(shader.globalsSize * 16, Dynamic, ConstantBuffer, CpuWrite, None, 0, null);
		// ctx.params = dx.Driver.createBuffer(shader.paramsSize * 16, Dynamic, ConstantBuffer, CpuWrite, None, 0, null);
		// ctx.samplersMap = [];

		// var samplers = new hxsl.HlslOut.Samplers();
		// for( v in shader.data.vars )
		// 	samplers.make(v, ctx.samplersMap);

		// #if debug
		// ctx.debugSource = shader.code;
		// #end
		// return { s : ctx, bytes : bytes };
	}

	override public function selectMaterial( pass : h3d.mat.Pass ) {
		trace("selectMaterial not implemented");
	}

	override public function uploadShaderBuffers( buffers : h3d.shader.Buffers, which : h3d.shader.Buffers.BufferKind ) {
		if (currentShader == null) {
			throw "Can't upload shader buffers without a current shader";
		}

		currentShader.vertex.uploadBuffer(this, buffers.vertex, which);
		currentShader.fragment.uploadBuffer(this, buffers.fragment, which);
		// @:privateAccess _uploadBuffer(currentShader.vertex, buffers.vertex, which);
		// @:privateAccess _uploadBuffer(currentShader.fragment, buffers.fragment, which);
	}

	override public function getShaderInputNames() : InputNames {
		throw "Not implemented";
	}

	override public function selectBuffer( buffer : Buffer ) {
		throw "Not implemented";
	}

	override public function selectMultiBuffers( buffers : Buffer.BufferOffset ) {
		throw "Not implemented";
	}

	override public function draw( ibuf : IndexBuffer, startIndex : Int, ntriangles : Int ) {
		throw "Not implemented";
	}

	override public function drawInstanced( ibuf : IndexBuffer, commands : h3d.impl.InstanceBuffer ) {
		throw "Not implemented";
	}

	override public function setRenderZone( x : Int, y : Int, width : Int, height : Int ) {
		throw "Not implemented";
	}

	override public function setRenderTarget( tex : Null<h3d.mat.Texture>, layer = 0, mipLevel = 0 ) {
		throw "Not implemented";
	}

	override public function setRenderTargets( textures : Array<h3d.mat.Texture> ) {
		throw "Not implemented";
	}

	override public function allocDepthBuffer( b : h3d.mat.DepthBuffer ) : DepthBuffer {
		if( b.format == null )
			@:privateAccess b.format = Depth32Stencil8;
		switch (b.format) {
			case Depth32Stencil8:
				trace('Allocating Depth32Stencil8');
				driver.setDepthStencilFormat(metal.MTLPixelFormat.MTLPixelFormatDepth32Float_Stencil8);
			default:
				throw "Unsupported depth format "+b.format;
		}

		return { }
	}

	override public function disposeDepthBuffer( b : h3d.mat.DepthBuffer ) {
		throw "Not implemented";
	}

	var defaultDepth : h3d.mat.DepthBuffer;

	override public function getDefaultDepthBuffer() : h3d.mat.DepthBuffer {
		if( defaultDepth != null )
			return defaultDepth;
		defaultDepth = new h3d.mat.DepthBuffer(0, 0);
		@:privateAccess {
			defaultDepth.width = this.bufferWidth;
			defaultDepth.height = this.bufferHeight;
			defaultDepth.b = allocDepthBuffer(defaultDepth);
		}
		return defaultDepth;
	}

	override public function end() {
		throw "Not implemented";
	}

	override public function setDebug(d) {
		this.debug = d;
	}

	private function _raiseNotImplIf( flags: haxe.EnumFlags<h3d.mat.Data.TextureFlags>, f: h3d.mat.Data.TextureFlags )
	{
		if (flags.has(f))
			throw '$f support not implemented';
	}

	function getTextureFormat( t : h3d.mat.Texture ) : metal.MTLPixelFormat {
		return switch( t.format ) {
		case RGBA: MTLPixelFormatRGBA8Unorm;
		case RGBA16F: MTLPixelFormatRGBA16Float;
		case RGBA32F: MTLPixelFormatRGBA32Float;
		case R32F: MTLPixelFormatR32Float;
		case R16F: MTLPixelFormatR16Float;
		case R8: MTLPixelFormatR8Unorm;
		case RG8: MTLPixelFormatRG8Unorm;
		case RG16F: MTLPixelFormatRG16Float;
		case RG32F: MTLPixelFormatRG32Float;
		case RGB10A2: MTLPixelFormatRGB10A2Unorm;
		case RG11B10UF: MTLPixelFormatRG11B10Float;
		case SRGB_ALPHA: MTLPixelFormatRGBA8Unorm_sRGB;
		case S3TC(n):
			switch( n ) {
			case 1: MTLPixelFormatBC1_RGBA;
			default: throw 'unsupported texture format ${t.format}';
			}
		default: throw "Unsupported texture format " + t.format;
		}
	}

	override public function allocTexture( t : h3d.mat.Texture ) : Texture {

		_raiseNotImplIf(t.flags, Target);
		_raiseNotImplIf(t.flags, Cube);
		_raiseNotImplIf(t.flags, ManualMipMapGen);
		_raiseNotImplIf(t.flags, IsNPOT);
		// _raiseNotImplIf(t.flags, NoAlloc);
		_raiseNotImplIf(t.flags, Dynamic);
		_raiseNotImplIf(t.flags, AlphaPremultiplied);
		// _raiseNotImplIf(t.flags, WasCleared);
		_raiseNotImplIf(t.flags, Loading);
		_raiseNotImplIf(t.flags, Serialize);
		_raiseNotImplIf(t.flags, IsArray);

		var mipmapped = t.flags.has(MipMapped);

		var textureDesc = new metal.MTLTextureDescriptor();
		textureDesc.width = t.width;
		textureDesc.height = t.height;
		textureDesc.pixelFormat = getTextureFormat(t);

		// TODO: is this ok?
		t.flags.unset(WasCleared);

		trace('allocTexture:
	mips ${t.mipLevels}
	width ${textureDesc.width}
	height ${textureDesc.height}
	pxfmt ${textureDesc.pixelFormat}
		');

		return driver.createTexture(textureDesc);
	}

	override public function allocIndexes( count : Int, is32 : Bool ) : IndexBuffer {
		trace('Allocate indexes $count $is32');
		var size = is32 ? 4 : 2;

		return { b: driver.createIndexBuffer( count * size ), is32: is32 };
	}

	override public function allocVertexes( m : ManagedBuffer ) : VertexBuffer {
		if( m.size * m.stride == 0 ) throw "size * stride can not be 0";
		return { b: driver.createVertexBuffer( m.size * m.stride * 4 ), stride: m.stride };
	}

	override public function allocInstanceBuffer( b : h3d.impl.InstanceBuffer, bytes : haxe.io.Bytes ) {
		throw "Not implemented";
	}

	override public function disposeTexture( t : h3d.mat.Texture ) {
		throw "Not implemented";
	}

	override public function disposeIndexes( i : IndexBuffer ) {
		throw "Not implemented";
	}

	override public function disposeVertexes( v : VertexBuffer ) {
		throw "Not implemented";
	}

	override public function disposeInstanceBuffer( b : h3d.impl.InstanceBuffer ) {
		throw "Not implemented";
	}

	override public function uploadIndexBuffer( i : IndexBuffer, startIndice : Int, indiceCount : Int, buf : hxd.IndexBuffer, bufPos : Int ) {

		var bits = i.is32 ? 2 : 1;
		var data = hl.Bytes.getArray(buf.getNative());

		trace('uploading buffer si $startIndice ic $indiceCount bp $bufPos');

		i.b.contentsMemcpy(
			hl.Bytes.getArray(buf.getNative()).offset(bufPos << bits),
			startIndice << bits,
			indiceCount << bits);

	}

	override public function uploadIndexBytes( i : IndexBuffer, startIndice : Int, indiceCount : Int, buf : haxe.io.Bytes , bufPos : Int ) {
		throw "Not implemented";
	}

	override public function uploadVertexBuffer( v : VertexBuffer, startVertex : Int, vertexCount : Int, buf : hxd.FloatBuffer, bufPos : Int )
	{
		var data = hl.Bytes.getArray(buf.getNative()).offset(bufPos<<2);

		v.b.contentsMemcpy(
			data,
			startVertex * v.stride << 2,
			vertexCount * v.stride << 2);
	}

	override public function uploadVertexBytes( v : VertexBuffer, startVertex : Int, vertexCount : Int, buf : haxe.io.Bytes, bufPos : Int ) {
		throw "Not implemented";
	}

	override public function uploadTextureBitmap( t : h3d.mat.Texture, bmp : hxd.BitmapData, mipLevel : Int, side : Int ) {
		throw "Not implemented";
	}

	override public function uploadTexturePixels( t : h3d.mat.Texture, pixels : hxd.Pixels, mipLevel : Int, side : Int ) {
		var region : metal.MTLRegion = {origin: {x: 0, y: 0, z: 0}, size: {width: t.width, height: t.height, depth: 1}};

		if( t.format.match(S3TC(_)) ) {
			throw "S3TC support not implemented";
		} else {
			if( t.flags.has(IsArray) )
			{
				throw "IsArray support not implemented";
			}
		}

		var stride = @:privateAccess pixels.stride;
		var bytes = (pixels.bytes:hl.Bytes).offset(pixels.offset);
		t.t.replace(region, mipLevel, bytes, stride);
	}

	override public function readVertexBytes( v : VertexBuffer, startVertex : Int, vertexCount : Int, buf : haxe.io.Bytes, bufPos : Int ) {
		throw "Driver does not allow to read vertex bytes";
	}

	override public function readIndexBytes( v : IndexBuffer, startVertex : Int, vertexCount : Int, buf : haxe.io.Bytes, bufPos : Int ) {
		throw "Driver does not allow to read index bytes";
	}

	/**
		Returns true if we could copy the texture, false otherwise (not supported by driver or mismatch in size/format)
	**/
	override public function copyTexture( from : h3d.mat.Texture, to : h3d.mat.Texture ) {
		trace("copyTexture");
		return false;
	}

	// --- QUERY API

	override public function allocQuery( queryKind : QueryKind ) : Query {
		trace("allocQuery");
		return null;
	}

	override public function deleteQuery( q : Query ) {
		trace("deleteQuery");
	}

	override public function beginQuery( q : Query ) {
		trace("beginQuery");
	}

	override public function endQuery( q : Query ) {
		trace("endQuery");
	}

	override public function queryResultAvailable( q : Query ) {
		trace("queryResultAvailable");
		return true;
	}

	override public function queryResult( q : Query ) {
		trace("queryResult");
		return 0.;
	}

}

#end

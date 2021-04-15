package h3d.impl;
import h3d.impl.Driver;

#if hlmetal

class MetalDriver extends Driver {

	var window: metal.Window;
	var driver: metal.Driver;
	var debug : Bool;

	var bufferWidth : Int;
	var bufferHeight : Int;


	// public var backBufferFormat : metal.Format = R8G8B8A8_UNORM;

	public function new(window: metal.Window) {
		this.window = window;
		this.driver = new metal.Driver(window);
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
			case HardwareAccelerated, AllocDepthBuffer:
				true;
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
		throw "Not implemented";
	}

	override public function generateMipMaps( texture : h3d.mat.Texture ) {
		throw "Mipmaps auto generation is not supported on this platform";
	}

	override public function getNativeShaderCode( shader : hxsl.RuntimeShader ) : String {
		throw "Not implemented";
	}

	override public function clear( ?color : h3d.Vector, ?depth : Float, ?stencil : Int ) {
		throw "Not implemented";
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
		throw "Not implemented";
	}

	override public function selectMaterial( pass : h3d.mat.Pass ) {
		throw "Not implemented";
	}

	override public function uploadShaderBuffers( buffers : h3d.shader.Buffers, which : h3d.shader.Buffers.BufferKind ) {
		throw "Not implemented";
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
			default: throw "assert";
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
		_raiseNotImplIf(t.flags, WasCleared);
		_raiseNotImplIf(t.flags, Loading);
		_raiseNotImplIf(t.flags, Serialize);
		_raiseNotImplIf(t.flags, IsArray);

		var mipmapped = t.flags.has(MipMapped);

		var textureDesc = new metal.Proxy_MTLTextureDescriptor();
		textureDesc.width = t.width;
		textureDesc.height = t.height;
		textureDesc.pixelFormat = getTextureFormat(t);

		trace('allocTexture:
	mips ${t.mipLevels}
	width ${textureDesc.width}
	height ${textureDesc.height}
	pxfmt ${textureDesc.pixelFormat}
		');

		return { t: driver.createTexture(textureDesc) };
	}

	override public function allocIndexes( count : Int, is32 : Bool ) : IndexBuffer {
		trace('Allocate indexes $count $is32');
		var size = is32 ? 4 : 2;

		return { b: driver.createIndexBuffer( count * size ), is32: is32 };
	}

	override public function allocVertexes( m : ManagedBuffer ) : VertexBuffer {
		if( m.size * m.stride == 0 ) throw "assert";
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

		driver.updateBuffer(
			i.b,
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

		driver.updateBuffer(
			v.b,
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
		throw "Not implemented";
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

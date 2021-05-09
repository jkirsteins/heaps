package hxsl;
using hxsl.Ast;

// class Samplers {

// 	public var count : Int;
// 	var named : Map<String, Int>;

// 	public function new() {
// 		count = 0;
// 		named = new Map();
// 	}

// 	public function make( v : TVar, arr : Array<Int> ) : Array<Int> {

// 		var ntex = switch( v.type ) {
// 		case TArray(t, SConst(k)) if( t.isSampler() ): k;
// 		case t if( t.isSampler() ): 1;
// 		default:
// 			return null;
// 		}

// 		var names = null;
// 		if( v.qualifiers != null ) {
// 			for( q in v.qualifiers ) {
// 				switch( q ) {
// 				case Sampler(nl): names = nl.split(",");
// 				default:
// 				}
// 			}
// 		}
// 		for( i in 0...ntex ) {
// 			if( names == null || names[i] == "" )
// 				arr.push(count++);
// 			else {
// 				var idx = named.get(names[i]);
// 				if( idx == null ) {
// 					idx = count++;
// 					named.set(names[i], idx);
// 				}
// 				arr.push(idx);
// 			}
// 		}
// 		return arr;
// 	}

// }

class MetalOut {

	static var KWD_LIST = [
		"s_input", "VertOutput", "_in", "_out", "in", "out", "mul", "matrix", "vector", "export", "half", "float", "double", "line", "linear", "point", "precise",
		"sample" // pssl
	];
	static var KWDS = [for( k in KWD_LIST ) k => true];
	static var GLOBALS = {
		var m = new Map();
		for( g in hxsl.Ast.TGlobal.createAll() ) {
			var n = "" + g;
			n = n.charAt(0).toLowerCase() + n.substr(1);
			m.set(g, n);
		}
		m.set(ToInt, "(int)");
		m.set(ToFloat, "(float)");
		m.set(ToBool, "(bool)");
		m.set(Vec2, "float2");
		m.set(Vec3, "float3");
		m.set(Vec4, "float4");
		m.set(LReflect, "reflect");
		m.set(Fract, "frac");
		m.set(Mix, "lerp");
		m.set(Inversesqrt, "rsqrt");
		m.set(VertexID,"_in.vertexID");
		m.set(InstanceID,"_in.instanceID");
		m.set(IVec2, "int2");
		m.set(IVec3, "int3");
		m.set(IVec4, "int3");
		m.set(BVec2, "bool2");
		m.set(BVec3, "bool3");
		m.set(BVec4, "bool4");
		m.set(FragCoord,"_in.__pos__");
		m.set(FrontFacing, "_in.isFrontFace");
		for( g in m )
			KWDS.set(g, true);
		m;
	};


    // converted
	var METAL_POSITION = "[[ position ]]";

    // Locals need to be populated after everything else, but emitted
    // above it. So we split writing into buffers
    var bufHead : StringBuf;  // header and structs
    var bufLocals : StringBuf;  // function locals
    var bufRest : StringBuf;    // everything after function locals
    var buf : StringBuf;    // pointer


    // not converted
    var SV_POSITION = "SV_POSITION";
	var SV_TARGET = "SV_TARGET";
	var SV_VertexID = "SV_VertexID";
	var SV_InstanceID = "SV_InstanceID";
	var SV_IsFrontFace = "SV_IsFrontFace";
	var STATIC = "static ";

    var exprIds = 0;
	var exprValues : Array<String>;
	var locals : Map<Int,TVar>;
	var decls : Array<String>;
	var isVertex : Bool;
	var allNames : Map<String, Int>;
	var samplers : Map<Int, Array<Int>>;
	public var varNames : Map<Int,String>;

	var varAccess : Map<Int,String>;

	public function new() {
		varNames = new Map();
		allNames = new Map();
	}

	inline function add( v : Dynamic ) {
		buf.add(v);
	}

	inline function ident( v : TVar ) {
		add(varName(v));
	}

	function decl( s : String ) {
		for( d in decls )
			if( d == s ) return;
		if( s.charCodeAt(0) == '#'.code )
			decls.unshift(s);
		else
			decls.push(s);
	}

	function addType( t : Type ) {
		switch( t ) {
		case TVoid:
			add("void");
		case TInt:
			add("int");
		case TBytes(n):
			add("uint"+n);
		case TBool:
			add("bool");
		case TFloat:
			add("float");
		case TString:
			add("string");
		case TVec(size, k):
			switch( k ) {
			case VFloat: add("float");
			case VInt: add("int");
			case VBool: add("bool");
			}
			add(size);
		case TMat2:
			add("float2x2");
		case TMat3:
			add("float3x3");
		case TMat4:
			add("float4x4");
		case TMat3x4:
			add("float4x3");
		case TSampler2D:
			add("texture2d<float>");
		case TSampler2DArray:
			add("texture2d_array<float>");
		case TStruct(vl):
			add("struct { ");
			for( v in vl ) {
				addVar(v);
				add(";");
			}
			add(" }");
		case TFun(_):
			add("function");
		case TArray(t, size), TBuffer(t,size):
			addType(t);
			add("[");
			switch( size ) {
			case SVar(v):
				ident(v);
			case SConst(v):
				add(v);
			}
			add("]");
		case TChannel(n):
			add("channel" + n);
        default:
            throw '${t} not implemented (reuse TArray?)';
		}
	}

	function addArraySize( size ) {
		add("[");
		switch( size ) {
		case SVar(v): ident(v);
		case SConst(n): add(n);
		}
		add("]");
	}

	function addVar( v : TVar ) {
		switch( v.type ) {
		// case TArray(TSampler2D, size):
		// 	var old = v.type;
		// 	v.type = TSampler2D;
		// 	addVar(v);
		// 	v.type = old;
		// 	addArraySize(size);
		// 	add('Yo${TSampler2D}');
		case TArray(t, size), TBuffer(t,size):
			add('array<');
			var old = v.type;
			v.type = t;
			addType(v.type);
			add(',');
			switch( size ) {
			case SVar(v): ident(v);
			case SConst(n): add(n);
			}
			add('> ');
			v.type = old;
			// addArraySize(size);
			ident(v);
			switch( t ) {
				case TSampler2D:
					add(' [[texture(0)]]');
				default:

			}
		default:
			addType(v.type);
			add(" ");
			ident(v);
		}
	}

	function addValue( e : TExpr, tabs : String ) {
		switch( e.e ) {
		case TBlock(el):
			var name = "val" + (exprIds++);
			var tmp = buf;
			buf = new StringBuf();
			addType(e.t);
			add(" ");
			add(name);
			add("(void)");
			var el2 = el.copy();
			var last = el2[el2.length - 1];
			el2[el2.length - 1] = { e : TReturn(last), t : e.t, p : last.p };
			var e2 = {
				t : TVoid,
				e : TBlock(el2),
				p : e.p,
			};
			addExpr(e2, "");
			exprValues.push(buf.toString());
			buf = tmp;
			add(name);
			add("()");
		case TIf(econd, eif, eelse):
			add("( ");
			addValue(econd, tabs);
			add(" ) ? ");
			addValue(eif, tabs);
			add(" : ");
			addValue(eelse, tabs);
		case TMeta(m,args,e):
			handleMeta(m, args, addValue, e, tabs);
		default:
			addExpr(e, tabs);
		}
	}

	function handleMeta( m, args : Array<Ast.Const>, callb, e, tabs ) {
		switch( [m, args] ) {
		default:
			callb(e,tabs);
		}
	}

	function addBlock( e : TExpr, tabs ) {
		if( e.e.match(TBlock(_)) )
			addExpr(e,tabs);
		else {
			add("{");
			addExpr(e,tabs);
			if( !isBlock(e) )
				add(";");
			add("}");
		}
	}

	function declMods() {
		// unsigned mod like GLSL
		decl("float mod(float x, float y) { return x - y * floor(x/y); }");
		decl("float2 mod(float2 x, float2 y) { return x - y * floor(x/y); }");
		decl("float3 mod(float3 x, float3 y) { return x - y * floor(x/y); }");
		decl("float4 mod(float4 x, float4 y) { return x - y * floor(x/y); }");
	}

	function addExpr( e : TExpr, tabs : String ) {
        switch( e.e ) {
		case TConst(c):
			switch( c ) {
			case CInt(v): add(v);
			case CFloat(f):
				var str = "" + f;
				add(str);
				if( str.indexOf(".") == -1 && str.indexOf("e") == -1 )
					add(".");
			case CString(v): add('"' + v + '"');
			case CNull: add("null");
			case CBool(b): add(b);
			}
		case TVar(v):
			var acc = varAccess.get(v.id);
			if( acc != null ) {
                add(acc);
            }
            if (v.kind == Input) {
				if (!isVertex) {
					throw 'not implemented';
				}
                add('__in[__in_vid].');
            }
            if (v.kind == Param) {
				if (isVertex) {
					add('__in_uniforms.');
				} else {
					switch( v.type ) {
						case TArray(TSampler2D, _):
							// should be passed as args to function
						default:
							add('__in_uniforms.');
					}
				}
            }
			if (v.kind == Global) {
				add('__in_globals.');
			}
            if (v.kind == Output || ( v.kind == Var && isVertex )) {
                add('__out.');
            }
            if ( v.kind == Var && !isVertex ) {
                add('__in.');
            }

            ident(v);
		case TCall({ e : TGlobal(g = (Texture | TextureLod)) }, args):
            // throw args[0];
			add('float4(');
			addValue(args[0], tabs);
            add('.sample(__default_textureSampler');
			// switch( g ) {
			// case Texture:
			// 	add(isVertex ? ".SampleLevel(" : ".Sample(");
			// case TextureLod:
			// 	add(".SampleLevel(");
			// default:
			// 	throw 'unsupported $g';
			// }
			// var offset = 0;
			// var expr = switch( args[0].e ) {
			// case TArray(e,{ e : TConst(CInt(i)) }): offset = i; e;
			// case TArray(e,{ e : TBinop(OpAdd,{e:TVar(_)},{e:TConst(CInt(_))}) }): throw "Offset in texture access: need loop unroll?";
			// default: args[0];
			// }
			// switch( expr.e ) {
			// case TVar(v):
			// 	var samplers = samplers.get(v.id);
			// 	if( samplers == null ) throw "no samplers";
			// 	add('__Samplers[${samplers[offset]}]');
			// default: throw "assert";
			// }
			for( i in 1...args.length ) {
				add(",");
				addValue(args[i],tabs);
			}
			// if( g == Texture && isVertex )
			// 	add(",0");
			add(")");
			add(")");
		case TCall({ e : TGlobal(g = (Texel)) }, args):
			addValue(args[0], tabs);
			add(".Load(");
			switch ( args[1].t ) {
				case TSampler2D:
					add("int3(");
				case TSampler2DArray:
					add("int4(");
				default:
					throw "assert";
			}
			addValue(args[1],tabs);
			if ( args.length != 2 ) {
				// with LOD argument
				add(", ");
				addValue(args[2], tabs);
			} else {
				add(", 0");
			}
			add("))");
		case TCall({ e : TGlobal(g = (TextureSize)) }, args):
			decl("float2 textureSize(Texture2D tex, int lod) { float w; float h; tex.GetDimensions(tex, (uint)lod, out w, out h); return float2(w, h); }");
			decl("float3 textureSize(Texture2DArray tex, int lod) { float w; float h; float els; tex.GetDimensions(tex, (uint)lod, out w, out h, out els); return float3(w, h, els); }");
			decl("float2 textureSize(TextureCube tex, int lod) { float w; float h; tex.GetDimensions(tex, (uint)lod, out w, out h); return float2(w, h); }");
			add("textureSize(");
			addValue(args[0], tabs);
			if (args.length != 1) {
				// With LOD argument
				add(", ");
				addValue(args[1],tabs);
			} else {
				add(", 0");
			}
			add(")");
		case TCall(e = { e : TGlobal(g) }, args):
			switch( [g,args.length] ) {
			case [Vec2, 1] if( args[0].t == TFloat ):
				decl("float2 vec2( float v ) { return float2(v,v); }");
				add("vec2");
			case [Vec3, 1] if( args[0].t == TFloat ):
				decl("float3 vec3( float v ) { return float3(v,v,v); }");
				add("vec3");
			case [Vec4, 1] if( args[0].t == TFloat ):
				decl("float4 vec4( float v ) { return float4(v,v,v,v); }");
				add("vec4");
			default:
				addValue(e,tabs);
			}
			add("(");
			var first = true;
			for( e in args ) {
				if( first ) first = false else add(", ");
				addValue(e, tabs);
			}
			add(")");
		case TGlobal(g):
			switch( g ) {
			case Mat3x4:
				// float4x3 constructor uses row-order, we want column order here
				decl("float4x3 mat3x4( float4 a, float4 b, float4 c ) { float4x3 m; m._m00_m10_m20_m30 = a; m._m01_m11_m21_m31 = b; m._m02_m12_m22_m32 = c; return m; }");
				decl("float4x3 mat3x4( float4x4 m ) { float4x3 m2; m2._m00_m10_m20_m30 = m._m00_m10_m20_m30; m2._m01_m11_m21_m31 = m._m01_m11_m21_m31; m2._m02_m12_m22_m32 = m._m02_m12_m22_m32; return m2; }");
			case Mat4:
				decl("float4x4 mat4( float4 a, float4 b, float4 c, float4 d ) { float4x4 m; m._m00_m10_m20_m30 = a; m._m01_m11_m21_m31 = b; m._m02_m12_m22_m32 = c; m._m03_m13_m23_m33 = d; return m; }");
			case Mat3:
				decl("float3x3 mat3( float4x4 m ) { return (float3x3)m; }");
				decl("float3x3 mat3( float4x3 m ) { return (float3x3)m; }");
				decl("float3x3 mat3( float3 a, float3 b, float3 c ) { float3x3 m; m._m00_m10_m20 = a; m._m01_m11_m21 = b; m._m02_m12_m22 = c; return m; }");
				decl("float3x3 mat3( float c00, float c01, float c02, float c10, float c11, float c12, float c20, float c21, float c22 ) { float3x3 m = { c00, c10, c20, c01, c11, c21, c02, c12, c22 }; return m; }");
			case Mat2:
				decl("float2x2 mat2( float4x4 m ) { return (float2x2)m; }");
				decl("float2x2 mat2( float4x3 m ) { return (float2x2)m; }");
				decl("float2x2 mat2( float3x3 m ) { return (float2x2)m; }");
				decl("float2x2 mat2( float2 a, float2 b ) { float2x2 m; m._m00_m10 = a; m._m01_m11 = b; return m; }");
				decl("float2x2 mat2( float c00, float c01, float c10, float c11 ) { float2x2 m = { c00, c10, c01, c11 }; return m; }");
			case Mod:
				declMods();
			case Pow:
				// negative power might not work
				decl("#pragma warning(disable:3571)");
			case Pack:
				decl("float4 pack( float v ) { float4 color = frac(v * float4(1, 255, 255.*255., 255.*255.*255.)); return color - color.yzww * float4(1. / 255., 1. / 255., 1. / 255., 0.); }");
			case Unpack:
				decl("float unpack( float4 color ) { return dot(color,float4(1., 1. / 255., 1. / (255. * 255.), 1. / (255. * 255. * 255.))); }");
			case PackNormal:
				decl("float4 packNormal( float3 n ) { return float4((n + 1.) * 0.5,1.); }");
			case UnpackNormal:
				decl("float3 unpackNormal( float4 p ) { return normalize(p.xyz * 2. - 1.); }");
			case Atan:
				decl("float atan( float y, float x ) { return atan2(y,x); }");
			case ScreenToUv:
				decl("float2 screenToUv( float2 v ) { return v * float2(0.5, -0.5) + float2(0.5,0.5); }");
			case UvToScreen:
				decl("float2 uvToScreen( float2 v ) { return v * float2(2.,-2.) + float2(-1., 1.); }");
			default:
			}
			add(GLOBALS.get(g));
		case TParenthesis(e):
			add("(");
			addValue(e,tabs);
			add(")");
		case TBlock(el):
			add("{\n");
			var t2 = tabs + "\t";
			for( e in el ) {
				add(t2);
				addExpr(e, t2);
				newLine(e);
			}
			add(tabs);
			add("}");
		case TVarDecl(v, { e : TArrayDecl(el) }):
			locals.set(v.id, v);
			for( i in 0...el.length ) {
				ident(v);
				add("[");
				add(i);
				add("] = ");
				addExpr(el[i], tabs);
				newLine(el[i]);
			}
		case TBinop(OpAssign,evar = { e : TVar(_) },{ e : TArrayDecl(el) }):
            for( i in 0...el.length ) {
				addExpr(evar, tabs);
				add("[");
				add(i);
				add("] = ");
				addExpr(el[i], tabs);
			}
        case TArrayDecl(el):
			add("{");
			var first = true;
			for( e in el ) {
				if( first ) first = false else add(", ");
				addValue(e,tabs);
			}
			add("}");
		case TBinop(op, e1, e2):
			switch( [op, e1.t, e2.t] ) {
			case [OpAssignOp(OpMod) | OpMod, _, _]:
				if( op.match(OpAssignOp(_)) ) {
					addValue(e1, tabs);
					add(" = ");
				}
				declMods();
				add("mod(");
				addValue(e1, tabs);
				add(",");
				addValue(e2, tabs);
				add(")");
			case [OpAssignOp(op), TVec(_), TMat3x4 | TMat3 | TMat4]:
				addValue(e1, tabs);
				add(" = ");
				addValue({ e : TBinop(op, e1, e2), t : e.t, p : e.p }, tabs);
			case [OpMult, TVec(_), TMat3x4]:
				add("mul(float4(");
				addValue(e1, tabs);
				add(",1.),");
				addValue(e2, tabs);
				add(")");
			case [OpMult, TVec(_), TMat2 | TMat3 | TMat4]:
				add("mul(");
				addValue(e1, tabs);
				add(",");
				addValue(e2, tabs);
				add(")");
			case [OpMult, TMat3 | TMat3x4 | TMat4, TMat3 | TMat3x4 | TMat4]:
				add("mul(");
				addValue(e1, tabs);
				add(",");
				addValue(e2, tabs);
				add(")");
			case [OpUShr, _, _]:
				decl("int _ushr( int a, int b) { return (int)(((unsigned int)a) >> b); }");
				add("_ushr(");
				addValue(e1, tabs);
				add(",");
				addValue(e2, tabs);
				add(")");
			default:
				addValue(e1, tabs);
				add(" ");
				add(Printer.opStr(op));
				add(" ");
				addValue(e2, tabs);
			}
		case TUnop(op, e1):
			add(switch(op) {
			case OpNot: "!";
			case OpNeg: "-";
			case OpIncrement: "++";
			case OpDecrement: "--";
			case OpNegBits: "~";
			default: throw "assert"; // OpSpread for Haxe4.2+
			});
			addValue(e1, tabs);
		case TVarDecl(v, init):
			locals.set(v.id, v);
			if( init != null ) {
				ident(v);
				add(" = ");
				addValue(init, tabs);
			} else {
				add("/*var*/");
			}
		case TCall(e, args):
			addValue(e, tabs);
			add("(");
			var first = true;
			for( e in args ) {
				if( first ) first = false else add(", ");
				addValue(e, tabs);
			}
			add(")");
		case TSwiz(e, regs):
			addValue(e, tabs);
			add(".");
			for( r in regs )
				add(switch(r) {
				case X: "x";
				case Y: "y";
				case Z: "z";
				case W: "w";
				});
		case TIf(econd, eif, eelse):
			add("if( ");
			addValue(econd, tabs);
			add(") ");
			addBlock(eif, tabs);
			if( eelse != null ) {
				add(" else ");
				addBlock(eelse, tabs);
			}
		case TDiscard:
			add("discard");
		case TReturn(e):
			if( e == null )
				add("return _out");
			else {
				add("return ");
				addValue(e, tabs);
			}
		case TFor(v, it, loop):
			locals.set(v.id, v);
			switch( it.e ) {
			case TBinop(OpInterval, e1, e2):
				add("[loop] for(");
				add(v.name+"=");
				addValue(e1,tabs);
				add(";"+v.name+"<");
				addValue(e2,tabs);
				add(";" + v.name+"++) ");
				addBlock(loop, tabs);
			default:
				throw "assert";
			}
		case TWhile(e, loop, false):
			var old = tabs;
			tabs += "\t";
			add("[loop] do ");
			addBlock(loop,tabs);
			add(" while( ");
			addValue(e,tabs);
			add(" )");
		case TWhile(e, loop, _):
			add("[loop] while( ");
			addValue(e, tabs);
			add(" ) ");
			addBlock(loop,tabs);
		case TSwitch(_):
			add("switch(...)");
		case TContinue:
			add("continue");
		case TBreak:
			add("break");
		case TArray(e, index):
			addValue(e, tabs);
			add("[");
			addValue(index, tabs);
			add("]");
		case TMeta(m, args, e):
			handleMeta(m, args, addExpr, e, tabs);
		}
	}

	function varName( v : TVar ) {
		var n = varNames.get(v.id);
		if( n != null )
			return n;
		n = v.name;
		while( KWDS.exists(n) )
			n = "_" + n;
		if( allNames.exists(n) ) {
			var k = 2;
			n += "_";
			while( allNames.exists(n + k) )
				k++;
			n += k;
		}
		varNames.set(v.id, n);
		allNames.set(n, v.id);
		return n;
	}

	function newLine( e : TExpr ) {
		if( isBlock(e) )
			add("\n");
		else
			add(";\n");
	}

	function isBlock( e : TExpr ) {
		switch( e.e ) {
		case TFor(_, _, loop), TWhile(_,loop,true):
			return isBlock(loop);
		case TIf(_,eif,eelse):
			return isBlock(eelse == null ? eif : eelse);
		case TBlock(_):
			return true;
		default:
			return false;
		}
	}

	function collectGlobals( m : Map<TGlobal,Bool>, e : TExpr ) {
		switch( e.e )  {
		case TGlobal(g): m.set(g,true);
		default: e.iter(collectGlobals.bind(m));
		}
	}

	function initVars( s : ShaderData ) {
		var index = 0;
		function declVar(directionIn: Bool, v : TVar ) {
			add("\t");
			addVar(v);
			if( v.kind == Output )
				add(" " + (isVertex ? METAL_POSITION : ""));
			add(";\n");

			// varAccess.set(v.id, prefix);
		}

		var foundGlobals = new Map();
		for( f in s.funs )
			collectGlobals(foundGlobals, f.expr);

		// params
        add("struct Uniforms {\n");
        for( v in s.vars ) {
			if( v.kind == Param ) {
				add("\t");
				addVar(v);
				add(";\n");
			}
        }
        add("};\n");

		// globals
		add("struct Globals {\n");
		for( v in s.vars )
			if( v.kind == Global ) {
				add("\t");
				addVar(v);
				add(";\n");
			}
		add("};\n\n");

		if (isVertex) {
			add("struct s_input {\n");
		} else {
			// frag input is vert output
			add("struct VertOutput {\n");
		}

		if( !isVertex )
			add("\tfloat4 position [[position]];\n");
		for( v in s.vars ) {
            if( v.kind == Input || (v.kind == Var && !isVertex) )
				declVar(true, v);
        }
		// if( foundGlobals.exists(VertexID) )
		// 	add("\tuint vertexID : "+SV_VertexID+";\n");
		// if( foundGlobals.exists(InstanceID) )
		// 	add("\tuint instanceID : "+SV_InstanceID+";\n");
		// if( foundGlobals.exists(FrontFacing) )
		// 	add("\tbool isFrontFace : "+SV_IsFrontFace+";\n");
		add("};\n\n");

        if (isVertex) {
		    add("struct VertOutput {\n");
        } else {
            add("struct FragOutput {\n");
        }

		for( v in s.vars )
			if( v.kind == Output )
				declVar(false, v);
		for( v in s.vars )
			if( v.kind == Var && isVertex )
				declVar(false, v);
		add("};\n\n");
	}

	// function initParams( s : ShaderData ) {
	// 	var textures = [];
	// 	var buffers = [];
	// 	add("cbuffer _params : register(b1) {\n");
	// 	for( v in s.vars )
	// 		if( v.kind == Param ) {
	// 			switch( v.type ) {
	// 			case TArray(t, _) if( t.isSampler() ):
	// 				textures.push(v);
	// 			case TBuffer(_):
	// 				buffers.push(v);
	// 				continue;
	// 			default:
	// 				if( v.type.isSampler() ) textures.push(v);
	// 			}
	// 			add("\t");
	// 			addVar(v);
	// 			add(";\n");
	// 		}
	// 	add("};\n\n");

	// 	var bufCount = 0;
	// 	for( b in buffers ) {
	// 		add('cbuffer _buffer$bufCount : register(b${bufCount+2}) { ');
	// 		addVar(b);
	// 		add("; };\n");
	// 		bufCount++;
	// 	}
	// 	if( bufCount > 0 ) add("\n");

	// 	var ctx = new Samplers();
	// 	for( v in textures )
	// 		samplers.set(v.id, ctx.make(v, []));

	// 	if( ctx.count > 0 )
	// 		add('SamplerState __Samplers[${ctx.count}];\n');
	// }

	// function initStatics( s : ShaderData ) {
	// 	add(STATIC + "s_input _in;\n");
	// 	add(STATIC + "VertOutput _out;\n");

	// 	add("\n");
	// 	for( v in s.vars )
	// 		if( v.kind == Local ) {
	// 			add(STATIC);
	// 			addVar(v);
	// 			add(";\n");
	// 		}
	// 	add("\n");
	// }

	function emitMain( s: ShaderData, expr : TExpr ) {

        buf = bufHead;

        var foundGlobals = new Map();
		for( f in s.funs )
			collectGlobals(foundGlobals, f.expr);

        function declMainArg(v : TVar ) {
			add("\t");
			addVar(v);
			if( v.kind == Output )
				add(" " + (isVertex ? METAL_POSITION : ""));
			add(",\n");

			// varAccess.set(v.id, prefix);
		}

		// tmp
		if (isVertex) {
			// add('struct s_input_dbg {');
			// add('	float2 position;');
			// add('	float2 uv;');
			// add('	float4 color;');
			// add('};');

			// add('vertex float4 vert_main(\n');
			// add('const device s_input_dbg* vertex_array [[ buffer(0) ]],\n');
			// add('unsigned int vid [[ vertex_id ]]) {\n');
			// add('return float4(vertex_array[vid].position, 1.0);\n');
			// add('}\n');
			// return;
		} else {
			// add('fragment half4 frag_main() {\n');
			// add('return half4(1.0, 0, 0, 1);\n');
			// add('}\n');
			// return;
		}
		// end tmp


        if (isVertex) {
            add("vertex VertOutput vert_main");
        } else {
            add("fragment FragOutput frag_main");
        }

		add("(\n");
        if( isVertex ) {
			add("\tunsigned int __in_vid [[vertex_id]],\n");
			add("\tconst device s_input *__in [[buffer(0)]],\n");
			add("\tconstant Uniforms &__in_uniforms [[buffer(1)]],\n");
			add("\tconstant Globals &__in_globals [[buffer(2)]]\n");
		} else {
			add("\tVertOutput __in [[stage_in]]");

			for( v in s.vars ) {
				if( v.kind == Param ) {
					switch( v.type ) {
						case TArray(_, _):
							add(",\n\t");
							addVar(v);
							break;
						default:
							throw 'fragment param ${v.type} not implemented';
					}
				}
			}
		}
        add(") {\n");

        if (isVertex) {
            add('\n\tVertOutput __out;\n');
        } else {
			add('\n\tconstexpr sampler __default_textureSampler (mag_filter::linear, min_filter::linear);');
			// add('\n\tsampler __default_textureSampler;');
			add('\n\tFragOutput __out;\n');
        }

        // skip locals for now
        buf = bufRest;

        switch( expr.e ) {
		case TBlock(el):
			for( e in el ) {
				add("\t");
				addExpr(e, "\t");
				newLine(e);
			}
		default:
			addExpr(expr, "");
		}

		// if (!isVertex) {
		// 	// temp: debug
		// 	add("if (is_null_texture(fragmentTextures))\n");
		// 	add("\t__out.OUTPUT1 = float4(0.0, 1.0, 0.0, 1.0);\n");
		// 	add("else\n");
		// 	add("\t__out.OUTPUT1 = fragmentTextures.sample(__default_textureSampler, float2(1.0, 1.0), level(0));\n");

		// }

		add("\treturn __out;\n");
		add("}");

        // now set the locals
        buf = bufLocals;

        // declared locals
        for( v in s.vars )
			if( v.kind == Local ) {
                add("\t");
				addVar(v);
				add(";\n");
			}

        // detected locals
        var locals = Lambda.array(locals);
		locals.sort(function(v1, v2) return Reflect.compare(v1.name, v2.name));
		for( v in locals ) {
            add("\t");
            addVar(v);
			add(";\n");
		}

        // now reset buf to the end
        buf = bufRest;
	}

	function initLocals() {
		var locals = Lambda.array(locals);
		locals.sort(function(v1, v2) return Reflect.compare(v1.name, v2.name));
		for( v in locals ) {
            addVar(v);
			add(";\n");
		}
		add("\n");

		for( e in exprValues ) {
            add(e);
			add("\n\n");
		}
	}

	public function run( s : ShaderData ) {
		locals = new Map();
		decls = [];

        bufHead = new StringBuf();
        bufLocals = new StringBuf();
        bufRest = new StringBuf();

        buf = bufHead;

		exprValues = [];

		if( s.funs.length != 1 ) throw "assert";
		var f = s.funs[0];
		isVertex = f.kind == Vertex;

		varAccess = new Map();
		samplers = new Map();


        decl("#include <metal_stdlib>");
        decl("using namespace metal;");

        initVars(s);
		// initGlobals(s);
		// initParams(s);
		// initStatics(s);
        // initLocals();

		// var tmp = buf;
		// buf = new StringBuf();
		emitMain(s, f.expr);
        // exprValues.push(buf.toString());
		// buf = tmp;



        decls.push(bufHead.toString());
        decls.push(bufLocals.toString());
        decls.push(bufRest.toString());
		buf = null;
        bufHead = null;
        bufLocals = null;
        bufRest = null;
		return decls.join("\n");
	}

	// public static function semanticName( name : String ) {
	// 	if( name.length == 0 || (name.charCodeAt(name.length - 1) >= '0'.code && name.charCodeAt(name.length - 1) <= '9'.code) )
	// 		name += "_";
	// 	return name;
	// }

}

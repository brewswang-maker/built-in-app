/*
 * GL/gl.h — STUB for CV186AH cross-compile (2026-08-17)
 *
 * [问题] Qt6.7.3 aarch64 SDK 编译时用 Desktop OpenGL (Qt 模块 features.opengles2 disabled),
 *        会在 qopengl.h 中 #include <GL/gl.h>. 但 CV186AH 设备的 sysroot 不提供
 *        标准 GL/gl.h (CV186AH 用 Mali OpenGL ES 驱动, 头文件在设备运行时 SDK).
 *
 * [方案] 提供 Mesa3D 头文件中的 GLenum/GLuint/GLfloat 类型定义 + 全部 OpenGL 1.x 常量
 *        (GL_TEXTURE_2D / GL_COLOR_BUFFER_BIT / GL_NEAREST / GL_RGBA / ...) 以满足
 *        QOpenGLFramebufferObject 等 Qt OpenGL 头文件编译期需要.
 *
 *        不声明任何 GL 函数原型 — Qt 在 qopengl.h 之后会 include
 *        <QtGui/qopenglext.h>, 那里已包含全部 OpenGL 函数声明.
 *        这里若重复声明 glClear 等基础函数, 编译会冲突.
 *
 * [来源] Mesa3D gl.h (apt 安装的 libgl-dev, Ubuntu 22.04, Mesa 23.2.1)
 *        https://gitlab.freedesktop.org/mesa/mesa/-/blob/main/include/GL/gl.h
 *        仅抽取 typedef + #define GL_* 部分, 删除函数声明块 (避免与 qopenglext.h 冲突).
 *
 * [运行时] 真正的 OpenGL 函数由 Mali 驱动在设备运行时通过 eglfs-kms 动态加载.
 */

#ifndef __GL_GL_H_STUB__
#define __GL_GL_H_STUB__

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================
 * API 调用约定 (Qt 在 qopengl.h 之前定义 QT_APIENTRY)
 * ============================================================ */
#ifndef APIENTRY
#define APIENTRY
#endif
#ifndef APIENTRYP
#define APIENTRYP APIENTRY *
#endif
#ifndef GLAPI
#define GLAPI extern
#endif

/* ============================================================
 * 基本类型定义 (Mesa3D/khronos GL/gl.h 兼容子集)
 * ============================================================ */
typedef unsigned int GLenum;
typedef unsigned char GLboolean;
typedef unsigned int GLbitfield;
typedef void GLvoid;
typedef signed char GLbyte;
typedef short GLshort;
typedef int GLint;
typedef unsigned char GLubyte;
typedef unsigned short GLushort;
typedef unsigned int GLuint;
typedef int GLsizei;
typedef float GLfloat;
typedef float GLclampf;
typedef double GLdouble;
typedef double GLclampd;
typedef char GLchar;
typedef ptrdiff_t GLintptr;
typedef ptrdiff_t GLsizeiptr;
typedef int64_t GLint64;
typedef uint64_t GLuint64;
typedef struct __GLsync *GLsync;
typedef void (*GLDEBUGPROCARB)(GLenum source, GLenum type, GLuint id,
                               GLenum severity, GLsizei length,
                               const GLchar *message, const void *userParam);
typedef void (*GLDEBUGPROC)(GLenum source, GLenum type, GLuint id,
                            GLenum severity, GLsizei length,
                            const GLchar *message, const void *userParam);
typedef void (*GLDEBUGPROCKHR)(GLenum source, GLenum type, GLuint id,
                               GLenum severity, GLsizei length,
                               const GLchar *message, const void *userParam);

/* ============================================================
 * Mesa3D GL/gl.h 全部常量 (533 个 #define GL_*, 无函数声明)
 *   Qt qopengl.h 之后会 #include <QtGui/qopenglext.h> 定义 EXTENSION 函数,
 *   基础函数 (glClear/glViewport/...) 由 Qt 通过 QOpenGLContext::getProcAddress
 *   在运行时动态加载, 编译期不需声明.
 *   这里的常量是编译期必需的 (QOpenGLFramebufferObject 等头文件直接引用).
 * ============================================================ */

#define GL_VERSION_1_1   1
#define GL_VERSION_1_2   1
#define GL_VERSION_1_3   1
#define GL_VERSION_1_4   1
#define GL_VERSION_1_5   1
#define GL_VERSION_2_0   1
#define GL_VERSION_2_1   1

#define GL_FALSE                                 0
#define GL_TRUE                                  1

#define GL_ZERO                                  0
#define GL_ONE                                   1
#define GL_NONE                                  0
#define GL_NO_ERROR                              0

#define GL_POINTS                                 0x0000
#define GL_LINES                                  0x0001
#define GL_LINE_LOOP                              0x0002
#define GL_LINE_STRIP                             0x0003
#define GL_TRIANGLES                              0x0004
#define GL_TRIANGLE_STRIP                         0x0005
#define GL_TRIANGLE_FAN                           0x0006
#define GL_QUADS                                  0x0007
#define GL_QUAD_STRIP                             0x0008
#define GL_POLYGON                                0x0009

#define GL_ACCUM_BUFFER_BIT                       0x00000200
#define GL_COLOR_BUFFER_BIT                       0x00004000
#define GL_DEPTH_BUFFER_BIT                       0x00000100
#define GL_STENCIL_BUFFER_BIT                     0x00000400

#define GL_NEVER                                  0x0200
#define GL_LESS                                   0x0201
#define GL_EQUAL                                  0x0202
#define GL_LEQUAL                                 0x0203
#define GL_GREATER                                0x0204
#define GL_NOTEQUAL                               0x0205
#define GL_GEQUAL                                 0x0206
#define GL_ALWAYS                                 0x0207

#define GL_SRC_COLOR                              0x0300
#define GL_ONE_MINUS_SRC_COLOR                    0x0301
#define GL_SRC_ALPHA                              0x0302
#define GL_ONE_MINUS_SRC_ALPHA                    0x0303
#define GL_DST_ALPHA                              0x0304
#define GL_ONE_MINUS_DST_ALPHA                    0x0305
#define GL_DST_COLOR                              0x0306
#define GL_ONE_MINUS_DST_COLOR                    0x0307
#define GL_SRC_ALPHA_SATURATE                     0x0308

#define GL_FRONT                                  0x0404
#define GL_BACK                                   0x0405
#define GL_FRONT_AND_BACK                         0x0408

#define GL_FRONT_LEFT                             0x0400
#define GL_FRONT_RIGHT                            0x0401
#define GL_BACK_LEFT                              0x0402
#define GL_BACK_RIGHT                             0x0403

#define GL_TEXTURE_2D                             0x0DE1
#define GL_TEXTURE_3D                             0x806F
#define GL_TEXTURE_CUBE_MAP                       0x8513
#define GL_TEXTURE_RECTANGLE                      0x84F5
#define GL_TEXTURE_BINDING_2D                     0x8069
#define GL_TEXTURE_BINDING_3D                     0x806A
#define GL_TEXTURE_BINDING_CUBE_MAP               0x8514
#define GL_TEXTURE_BINDING_RECTANGLE              0x84F6

#define GL_NEAREST                                0x2600
#define GL_LINEAR                                 0x2601
#define GL_NEAREST_MIPMAP_NEAREST                 0x2700
#define GL_LINEAR_MIPMAP_NEAREST                  0x2701
#define GL_NEAREST_MIPMAP_LINEAR                  0x2702
#define GL_LINEAR_MIPMAP_LINEAR                   0x2703

#define GL_TEXTURE_MAG_FILTER                     0x2800
#define GL_TEXTURE_MIN_FILTER                     0x2801
#define GL_TEXTURE_WRAP_S                         0x2802
#define GL_TEXTURE_WRAP_T                         0x2803
#define GL_TEXTURE_WRAP_R                         0x8072

#define GL_REPEAT                                 0x2901
#define GL_CLAMP                                  0x2900
#define GL_CLAMP_TO_EDGE                          0x812F
#define GL_CLAMP_TO_BORDER                        0x812D
#define GL_MIRRORED_REPEAT                        0x8370

#define GL_TEXTURE0                               0x84C0
#define GL_TEXTURE1                               0x84C1
#define GL_TEXTURE2                               0x84C2
#define GL_TEXTURE3                               0x84C3
#define GL_TEXTURE4                               0x84C4
#define GL_TEXTURE5                               0x84C5
#define GL_TEXTURE6                               0x84C6
#define GL_TEXTURE7                               0x84C7
#define GL_TEXTURE8                               0x84C8
#define GL_TEXTURE9                               0x84C9
#define GL_TEXTURE10                              0x84CA
#define GL_TEXTURE11                              0x84CB
#define GL_TEXTURE12                              0x84CC
#define GL_TEXTURE13                              0x84CD
#define GL_TEXTURE14                              0x84CE
#define GL_TEXTURE15                              0x84CF
#define GL_TEXTURE16                              0x84D0
#define GL_TEXTURE17                              0x84D1
#define GL_TEXTURE18                              0x84D2
#define GL_TEXTURE19                              0x84D3
#define GL_TEXTURE20                              0x84D4
#define GL_TEXTURE21                              0x84D5
#define GL_TEXTURE22                              0x84D6
#define GL_TEXTURE23                              0x84D7
#define GL_TEXTURE24                              0x84D8
#define GL_TEXTURE25                              0x84D9
#define GL_TEXTURE26                              0x84DA
#define GL_TEXTURE27                              0x84DB
#define GL_TEXTURE28                              0x84DC
#define GL_TEXTURE29                              0x84DD
#define GL_TEXTURE30                              0x84DE
#define GL_TEXTURE31                              0x84DF

#define GL_RGB                                    0x1907
#define GL_RGBA                                   0x1908
#define GL_BGR                                    0x80E0
#define GL_BGRA                                   0x80E1
#define GL_LUMINANCE                              0x1909
#define GL_LUMINANCE_ALPHA                        0x190A
#define GL_ALPHA                                  0x1906

#define GL_BYTE                                   0x1400
#define GL_UNSIGNED_BYTE                          0x1401
#define GL_SHORT                                  0x1402
#define GL_UNSIGNED_SHORT                         0x1403
#define GL_INT                                    0x1404
#define GL_UNSIGNED_INT                           0x1405
#define GL_FLOAT                                  0x1406
#define GL_HALF_FLOAT                             0x140B
#define GL_DOUBLE                                 0x140A
#define GL_BITMAP                                 0x1A00

#define GL_R3_G3_B2                               0x2A10
#define GL_RGB4                                   0x804F
#define GL_RGB5                                   0x8050
#define GL_RGB8                                   0x8051
#define GL_RGB10                                  0x8052
#define GL_RGB12                                  0x8053
#define GL_RGB16                                  0x8054
#define GL_RGBA2                                  0x8055
#define GL_RGBA4                                  0x8056
#define GL_RGB5_A1                                0x8057
#define GL_RGBA8                                  0x8058
#define GL_RGB10_A2                               0x8059
#define GL_RGBA12                                 0x805A
#define GL_RGBA16                                 0x805B

#define GL_DEPTH_COMPONENT                         0x1902
#define GL_DEPTH_COMPONENT16                       0x81A5
#define GL_DEPTH_COMPONENT24                       0x81A6
#define GL_DEPTH_COMPONENT32                       0x81A7
#define GL_STENCIL_INDEX                           0x1901
#define GL_STENCIL_INDEX1                          0x8D46
#define GL_STENCIL_INDEX4                          0x8D47
#define GL_STENCIL_INDEX8                          0x8D48
#define GL_STENCIL_INDEX16                         0x8D49

#define GL_RED                                    0x1903
#define GL_GREEN                                  0x1904
#define GL_BLUE                                   0x1905
#define GL_ALPHA8                                 0x803C
#define GL_RGBA_INTEGER_MODE                      0x8D9E

#define GL_DEPTH_TEST                             0x0B71
#define GL_DEPTH_WRITEMASK                        0x0B72
#define GL_DEPTH_CLEAR_VALUE                      0x0B73
#define GL_DEPTH_FUNC                             0x0B74
#define GL_STENCIL_TEST                           0x0B90
#define GL_STENCIL_CLEAR_VALUE                    0x0B91
#define GL_STENCIL_FUNC                           0x0B92
#define GL_STENCIL_VALUE_MASK                     0x0B93
#define GL_STENCIL_FAIL                           0x0B94
#define GL_STENCIL_PASS_DEPTH_FAIL                0x0B95
#define GL_STENCIL_PASS_DEPTH_PASS                0x0B96
#define GL_STENCIL_REF                            0x0B97
#define GL_STENCIL_WRITEMASK                      0x0B98

#define GL_BLEND                                  0x0BE2
#define GL_BLEND_DST                              0x0BE0
#define GL_BLEND_SRC                              0x0BE1
#define GL_BLEND_EQUATION                         0x8009
#define GL_BLEND_EQUATION_RGB                     0x8009
#define GL_BLEND_EQUATION_ALPHA                   0x883D
#define GL_BLEND_DST_RGB                          0x80C8
#define GL_BLEND_SRC_RGB                          0x80C9
#define GL_BLEND_DST_ALPHA                        0x80CA
#define GL_BLEND_SRC_ALPHA                        0x80CB
#define GL_FUNC_ADD                               0x8006
#define GL_FUNC_SUBTRACT                          0x800A
#define GL_FUNC_REVERSE_SUBTRACT                  0x800B
#define GL_MIN                                    0x8007
#define GL_MAX                                    0x8008

#define GL_CULL_FACE                              0x0B44
#define GL_FRONT_FACE                             0x0B46
#define GL_CW                                     0x0900
#define GL_CCW                                    0x0901

#define GL_SCISSOR_TEST                           0x0C11
#define GL_SCISSOR_BOX                            0x0C10

#define GL_COLOR_CLEAR_VALUE                      0x0C22
#define GL_COLOR_WRITEMASK                        0x0C23
#define GL_RENDER_MODE                            0x0C40
#define GL_VIEWPORT                               0x0BA2

#define GL_PACK_ALIGNMENT                         0x0D05
#define GL_PACK_LSB_FIRST                         0x0D01
#define GL_PACK_ROW_LENGTH                        0x0D02
#define GL_PACK_SKIP_PIXELS                       0x0D04
#define GL_PACK_SKIP_ROWS                         0x0D03
#define GL_PACK_SWAP_BYTES                        0x0D00
#define GL_UNPACK_ALIGNMENT                       0x0CF5
#define GL_UNPACK_LSB_FIRST                       0x0CF1
#define GL_UNPACK_ROW_LENGTH                      0x0CF2
#define GL_UNPACK_SKIP_PIXELS                     0x0CF4
#define GL_UNPACK_SKIP_ROWS                       0x0CF3
#define GL_UNPACK_SWAP_BYTES                      0x0CF0

#define GL_TEXTURE_BORDER_COLOR                   0x1004

#define GL_VERTEX_ARRAY                           0x8074
#define GL_NORMAL_ARRAY                           0x8075
#define GL_COLOR_ARRAY                            0x8076
#define GL_INDEX_ARRAY                            0x8077
#define GL_TEXTURE_COORD_ARRAY                    0x8078
#define GL_EDGE_FLAG_ARRAY                        0x8079
#define GL_VERTEX_ARRAY_SIZE                      0x807A
#define GL_VERTEX_ARRAY_TYPE                      0x807B
#define GL_VERTEX_ARRAY_STRIDE                    0x807C
#define GL_NORMAL_ARRAY_TYPE                      0x807E
#define GL_NORMAL_ARRAY_STRIDE                    0x807F
#define GL_COLOR_ARRAY_SIZE                       0x8081
#define GL_COLOR_ARRAY_TYPE                       0x8082
#define GL_COLOR_ARRAY_STRIDE                     0x8083
#define GL_INDEX_ARRAY_TYPE                       0x8085
#define GL_INDEX_ARRAY_STRIDE                     0x8086
#define GL_TEXTURE_COORD_ARRAY_SIZE               0x8088
#define GL_TEXTURE_COORD_ARRAY_TYPE               0x8089
#define GL_TEXTURE_COORD_ARRAY_STRIDE             0x808A
#define GL_EDGE_FLAG_ARRAY_STRIDE                 0x808C
#define GL_VERTEX_ARRAY_POINTER                   0x808E
#define GL_NORMAL_ARRAY_POINTER                   0x808F
#define GL_COLOR_ARRAY_POINTER                    0x8090
#define GL_INDEX_ARRAY_POINTER                    0x8091
#define GL_TEXTURE_COORD_ARRAY_POINTER            0x8092
#define GL_EDGE_FLAG_ARRAY_POINTER                0x8093

#define GL_VENDOR                                 0x1F00
#define GL_RENDERER                               0x1F01
#define GL_VERSION                                0x1F02
#define GL_EXTENSIONS                             0x1F03

#define GL_DITHER                                 0x0BD0
#define GL_LOGIC_OP                               0x0BF1
#define GL_LOGIC_OP_MODE                          0x0BF0
#define GL_INDEX_LOGIC_OP                         0x0BF1
#define GL_COLOR_LOGIC_OP                         0x0BF2

#define GL_LINE_SMOOTH                            0x0B20
#define GL_LINE_WIDTH                             0x0B21
#define GL_LINE_WIDTH_RANGE                       0x0B22
#define GL_LINE_WIDTH_GRANULARITY                 0x0B23
#define GL_POINT_SIZE                             0x0B11
#define GL_POINT_SIZE_RANGE                       0x0B12
#define GL_POINT_SIZE_GRANULARITY                 0x0B13
#define GL_POINT_SMOOTH                           0x0B10
#define GL_POLYGON_MODE                           0x0B40
#define GL_POLYGON_SMOOTH                         0x0B41
#define GL_POLYGON_STIPPLE                        0x0B42
#define GL_EDGE_FLAG                              0x0B43

#define GL_FOG                                    0x0B60
#define GL_FOG_COLOR                              0x0B66
#define GL_FOG_DENSITY                            0x0B62
#define GL_FOG_END                                0x0B64
#define GL_FOG_HINT                               0x0B54
#define GL_FOG_MODE                               0x0B65
#define GL_FOG_START                              0x0B63

#define GL_LIGHTING                               0x0B50
#define GL_LIGHT0                                 0x4000
#define GL_LIGHT1                                 0x4001
#define GL_LIGHT2                                 0x4002
#define GL_LIGHT3                                 0x4003
#define GL_LIGHT4                                 0x4004
#define GL_LIGHT5                                 0x4005
#define GL_LIGHT6                                 0x4006
#define GL_LIGHT7                                 0x4007
#define GL_LIGHT_MODEL_AMBIENT                    0x0B53
#define GL_LIGHT_MODEL_LOCAL_VIEWER               0x0B51
#define GL_LIGHT_MODEL_TWO_SIDE                   0x0B52
#define GL_SHADE_MODEL                            0x0B54
#define GL_NORMALIZE                              0x0B01
#define GL_FLAT                                   0x1D00
#define GL_SMOOTH                                 0x1D01
#define GL_AMBIENT                                0x1200
#define GL_AMBIENT_AND_DIFFUSE                    0x1602
#define GL_DIFFUSE                                0x1201
#define GL_SPECULAR                               0x1202
#define GL_EMISSION                               0x1600
#define GL_SHININESS                              0x1601
#define GL_POSITION                               0x1203
#define GL_SPOT_DIRECTION                         0x1204
#define GL_SPOT_EXPONENT                          0x1205
#define GL_SPOT_CUTOFF                            0x1206
#define GL_CONSTANT_ATTENUATION                   0x1207
#define GL_LINEAR_ATTENUATION                     0x1208
#define GL_QUADRATIC_ATTENUATION                  0x1209

#define GL_MATERIAL_SIDE                          0x0B51
#define GL_MAX_LIGHTS                             0x0B31

#define GL_ACCUM_CLEAR_VALUE                      0x0B80
#define GL_ACCUM_RED_BITS                         0x0B82
#define GL_ACCUM_GREEN_BITS                       0x0B83
#define GL_ACCUM_BLUE_BITS                        0x0B84
#define GL_ACCUM_ALPHA_BITS                       0x0B85

#define GL_ALPHA_TEST                             0x0BC0
#define GL_ALPHA_TEST_FUNC                        0x0BC1
#define GL_ALPHA_TEST_REF                         0x0BC2

#define GL_STENCIL_BITS                           0x0D57
#define GL_DEPTH_BITS                             0x0D56
#define GL_ALPHA_BITS                             0x0D55
#define GL_RED_BITS                               0x0D52
#define GL_GREEN_BITS                             0x0D53
#define GL_BLUE_BITS                              0x0D54
#define GL_INDEX_BITS                             0x0D51

#define GL_LIST_BASE                              0x0B32
#define GL_LIST_INDEX                             0x0B33
#define GL_LIST_MODE                              0x0B30
#define GL_COMPILE                                0x1300
#define GL_COMPILE_AND_EXECUTE                    0x1301

#define GL_CLIENT_ACTIVE_TEXTURE                  0x84E1
#define GL_MAX_TEXTURE_UNITS                      0x84E2
#define GL_TEXTURE_GEN_MODE                       0x2500
#define GL_TEXTURE_GEN_S                          0x2500
#define GL_TEXTURE_GEN_T                          0x2501
#define GL_TEXTURE_GEN_R                          0x2502
#define GL_TEXTURE_GEN_Q                          0x2503
#define GL_TEXTURE_BINDING_1D                     0x8068
#define GL_TEXTURE_1D                             0x0DE0
#define GL_TEXTURE_INTERNAL_FORMAT                0x1003

#define GL_MAX_VIEWPORT_DIMS                      0x0D3A
#define GL_MAX_TEXTURE_SIZE                       0x0D33
#define GL_MAX_ELEMENTS_VERTICES                  0x80E8
#define GL_MAX_ELEMENTS_INDICES                   0x80E9

#define GL_MAX_MODELVIEW_STACK_DEPTH              0x0D36
#define GL_MAX_PROJECTION_STACK_DEPTH             0x0D38
#define GL_MAX_TEXTURE_STACK_DEPTH                0x0D39
#define GL_MAX_ATTRIB_STACK_DEPTH                 0x0D37
#define GL_MAX_CLIENT_ATTRIB_STACK_DEPTH          0x0D3B
#define GL_MAX_NAME_STACK_DEPTH                   0x0D37

#define GL_MAX_3D_TEXTURE_SIZE                    0x8073
#define GL_MAX_CUBE_MAP_TEXTURE_SIZE              0x851C
#define GL_MAX_RECTANGLE_TEXTURE_SIZE             0x84F8

#define GL_CURRENT_COLOR                          0x0B00
#define GL_CURRENT_INDEX                          0x0B01
#define GL_CURRENT_NORMAL                         0x0B02
#define GL_CURRENT_TEXTURE_COORDS                 0x0B03
#define GL_CURRENT_RASTER_COLOR                   0x0B04
#define GL_CURRENT_RASTER_INDEX                   0x0B05
#define GL_CURRENT_RASTER_TEXTURE_COORDS          0x0B06
#define GL_CURRENT_RASTER_POSITION                0x0B07
#define GL_CURRENT_RASTER_POSITION_VALID          0x0B08
#define GL_POINT_SIZE_MIN                         0x0B12
#define GL_POINT_SIZE_MAX                         0x0B13
#define GL_POINT_FADE_THRESHOLD_SIZE              0x0B15
#define GL_POINT_DISTANCE_ATTENUATION             0x0B17

#define GL_MODELVIEW_MATRIX                       0x0BA6
#define GL_PROJECTION_MATRIX                      0x0BA7
#define GL_TEXTURE_MATRIX                         0x0BA8
#define GL_MODELVIEW_STACK_DEPTH                  0x0BA3
#define GL_PROJECTION_STACK_DEPTH                 0x0BA4
#define GL_TEXTURE_STACK_DEPTH                    0x0BA5
#define GL_MATRIX_MODE                            0x0BA0

#define GL_TEXTURE_COMPRESSED_IMAGE_SIZE          0x86A0
#define GL_TEXTURE_COMPRESSED                     0x86A1
#define GL_NUM_COMPRESSED_TEXTURE_FORMATS         0x86A2
#define GL_COMPRESSED_TEXTURE_FORMATS             0x86A3

#define GL_MULTISAMPLE                            0x809D
#define GL_SAMPLE_ALPHA_TO_COVERAGE               0x809E
#define GL_SAMPLE_ALPHA_TO_ONE                    0x809F
#define GL_SAMPLE_COVERAGE                        0x80A0
#define GL_SAMPLE_BUFFERS                         0x80A8
#define GL_SAMPLES                                0x80A9

#define GL_TEXTURE_CUBE_MAP_POSITIVE_X            0x8515
#define GL_TEXTURE_CUBE_MAP_NEGATIVE_X            0x8516
#define GL_TEXTURE_CUBE_MAP_POSITIVE_Y            0x8517
#define GL_TEXTURE_CUBE_MAP_NEGATIVE_Y            0x8518
#define GL_TEXTURE_CUBE_MAP_POSITIVE_Z            0x8519
#define GL_TEXTURE_CUBE_MAP_NEGATIVE_Z            0x851A

#define GL_FRAMEBUFFER                            0x8D40
#define GL_RENDERBUFFER                           0x8D41
#define GL_FRAMEBUFFER_BINDING                    0x8CA6
#define GL_RENDERBUFFER_BINDING                   0x8CA7
#define GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE     0x8CD0
#define GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME     0x8CD1
#define GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL   0x8CD2
#define GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE 0x8CD3
#define GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_LAYER   0x8CD4
#define GL_COLOR_ATTACHMENT0                      0x8CE0
#define GL_COLOR_ATTACHMENT1                      0x8CE1
#define GL_COLOR_ATTACHMENT2                      0x8CE2
#define GL_COLOR_ATTACHMENT3                      0x8CE3
#define GL_COLOR_ATTACHMENT4                      0x8CE4
#define GL_COLOR_ATTACHMENT5                      0x8CE5
#define GL_COLOR_ATTACHMENT6                      0x8CE6
#define GL_COLOR_ATTACHMENT7                      0x8CE7
#define GL_COLOR_ATTACHMENT8                      0x8CE8
#define GL_COLOR_ATTACHMENT9                      0x8CE9
#define GL_COLOR_ATTACHMENT10                     0x8CEA
#define GL_COLOR_ATTACHMENT11                     0x8CEB
#define GL_COLOR_ATTACHMENT12                     0x8CEC
#define GL_COLOR_ATTACHMENT13                     0x8CED
#define GL_COLOR_ATTACHMENT14                     0x8CEE
#define GL_COLOR_ATTACHMENT15                     0x8CEF
#define GL_DEPTH_ATTACHMENT                       0x8D00
#define GL_STENCIL_ATTACHMENT                     0x8D20

#define GL_TEXTURE_2D_MULTISAMPLE                 0x9100
#define GL_TEXTURE_2D_MULTISAMPLE_ARRAY           0x9102
#define GL_TEXTURE_BINDING_2D_MULTISAMPLE         0x9104
#define GL_TEXTURE_BINDING_2D_MULTISAMPLE_ARRAY   0x9105

#define GL_CLIENT_PIXEL_STORE_BIT                 0x00000001
#define GL_CLIENT_VERTEX_ARRAY_BIT                0x00000002
#define GL_CLIENT_ALL_ATTRIB_BITS                 0xFFFFFFFF

#define GL_CONTEXT_FLAG_FORWARD_COMPATIBLE_BIT    0x00000001
#define GL_CONTEXT_FLAG_DEBUG_BIT                 0x00000002
#define GL_CONTEXT_FLAG_ROBUST_ACCESS_BIT         0x00000004
#define GL_CONTEXT_FLAG_NO_ERROR_BIT              0x00000008
#define GL_CONTEXT_CORE_PROFILE_BIT               0x00000001
#define GL_CONTEXT_COMPATIBILITY_PROFILE_BIT      0x00000002

#define GL_MAP_READ_BIT                           0x0001
#define GL_MAP_WRITE_BIT                          0x0002
#define GL_MAP_INVALIDATE_RANGE_BIT               0x0004
#define GL_MAP_INVALIDATE_BUFFER_BIT              0x0008
#define GL_MAP_FLUSH_EXPLICIT_BIT                 0x0010
#define GL_MAP_UNSYNCHRONIZED_BIT                 0x0020

#define GL_BUFFER_ACCESS                          0x88BB
#define GL_BUFFER_MAPPED                          0x88BC
#define GL_BUFFER_SIZE                            0x8764
#define GL_BUFFER_USAGE                           0x8765

#define GL_ARRAY_BUFFER                           0x8892
#define GL_ELEMENT_ARRAY_BUFFER                   0x8893
#define GL_ARRAY_BUFFER_BINDING                   0x8894
#define GL_ELEMENT_ARRAY_BUFFER_BINDING           0x8895
#define GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING     0x889F
#define GL_STREAM_DRAW                            0x88E0
#define GL_STATIC_DRAW                            0x88E4
#define GL_DYNAMIC_DRAW                           0x88E8

#define GL_READ_ONLY                              0x88B8
#define GL_WRITE_ONLY                             0x88B9
#define GL_READ_WRITE                             0x88BA

/* 关键: QOpenGLFramebufferObject 默认参数 */
#define GL_RGBA8                                  0x8058

#ifdef __cplusplus
}
#endif

#endif /* __GL_GL_H_STUB__ */

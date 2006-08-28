#!/usr/bin/perl -w
#
# A script to generate optimized C blitters for Simple DirectMedia Layer
# http://www.libsdl.org/

use warnings;
use strict;

my %file;

# The formats potentially supported by this script:
# SDL_PIXELFORMAT_INDEX8
# SDL_PIXELFORMAT_RGB332
# SDL_PIXELFORMAT_RGB444
# SDL_PIXELFORMAT_RGB555
# SDL_PIXELFORMAT_ARGB4444
# SDL_PIXELFORMAT_ARGB1555
# SDL_PIXELFORMAT_RGB565
# SDL_PIXELFORMAT_RGB24
# SDL_PIXELFORMAT_BGR24
# SDL_PIXELFORMAT_RGB888
# SDL_PIXELFORMAT_BGR888
# SDL_PIXELFORMAT_ARGB8888
# SDL_PIXELFORMAT_RGBA8888
# SDL_PIXELFORMAT_ABGR8888
# SDL_PIXELFORMAT_BGRA8888
# SDL_PIXELFORMAT_ARGB2101010

# The formats we're actually creating blitters for:
my @src_formats = (
    "RGB888",
    "BGR888",
    "ARGB8888",
    "RGBA8888",
    "ABGR8888",
    "BGRA8888",
);
my @dst_formats = (
    "RGB888",
    "BGR888",
);

my %format_size = (
    "RGB888" => 4,
    "BGR888" => 4,
    "ARGB8888" => 4,
    "RGBA8888" => 4,
    "ABGR8888" => 4,
    "BGRA8888" => 4,
);

my %format_type = (
    "RGB888" => "Uint32",
    "BGR888" => "Uint32",
    "ARGB8888" => "Uint32",
    "RGBA8888" => "Uint32",
    "ABGR8888" => "Uint32",
    "BGRA8888" => "Uint32",
);

my %get_rgba_string = (
    "RGB888" => "_R = (Uint8)(_pixel >> 16); _G = (Uint8)(_pixel >> 8); _B = (Uint8)_pixel; _A = 0xFF;",
    "BGR888" => "_B = (Uint8)(_pixel >> 16); _G = (Uint8)(_pixel >> 8); _R = (Uint8)_pixel; _A = 0xFF;",
    "ARGB8888" => "_A = (Uint8)(_pixel >> 24); _R = (Uint8)(_pixel >> 16); _G = (Uint8)(_pixel >> 8); _B = (Uint8)_pixel;",
    "RGBA8888" => "_R = (Uint8)(_pixel >> 24); _G = (Uint8)(_pixel >> 16); _B = (Uint8)(_pixel >> 8); _A = (Uint8)_pixel;",
    "ABGR8888" => "_A = (Uint8)(_pixel >> 24); _B = (Uint8)(_pixel >> 16); _G = (Uint8)(_pixel >> 8); _R = (Uint8)_pixel;",
    "BGRA8888" => "_B = (Uint8)(_pixel >> 24); _G = (Uint8)(_pixel >> 16); _R = (Uint8)(_pixel >> 8); _A = (Uint8)_pixel;",
);

my %set_rgba_string = (
    "RGB888" => "_pixel = ((Uint32)_R << 16) | ((Uint32)_G << 8) | _B;",
    "BGR888" => "_pixel = ((Uint32)_B << 16) | ((Uint32)_G << 8) | _R;",
);

sub open_file {
    my $name = shift;
    open(FILE, ">$name.new") || die "Cant' open $name.new: $!";
    print FILE <<__EOF__;
/* DO NOT EDIT!  This file is generated by sdlgenblit.pl */
/*
    SDL - Simple DirectMedia Layer
    Copyright (C) 1997-2006 Sam Lantinga

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

    Sam Lantinga
    slouken\@libsdl.org
*/
#include "SDL_config.h"

/* *INDENT-OFF* */

__EOF__
}

sub close_file {
    my $name = shift;
    print FILE <<__EOF__;
/* *INDENT-ON* */

/* vi: set ts=4 sw=4 expandtab: */
__EOF__
    close FILE;
    if ( ! -f $name || system("cmp -s $name $name.new") != 0 ) {
        rename("$name.new", "$name");
    } else {
        unlink("$name.new");
    }
}

sub output_copydefs
{
    print FILE <<__EOF__;
#define SDL_RENDERCOPY_MODULATE_COLOR   0x0001
#define SDL_RENDERCOPY_MODULATE_ALPHA   0x0002
#define SDL_RENDERCOPY_BLEND            0x0010
#define SDL_RENDERCOPY_ADD              0x0020
#define SDL_RENDERCOPY_MOD              0x0040
#define SDL_RENDERCOPY_NEAREST          0x0100

typedef struct {
    void *src;
    int src_w, src_h;
    int src_pitch;
    void *dst;
    int dst_w, dst_h;
    int dst_pitch;
    void *aux_data;
    int flags;
    Uint8 r, g, b, a;
} SDL_RenderCopyData;

typedef int (*SDL_RenderCopyFunc)(SDL_RenderCopyData *data);

extern SDL_RenderCopyFunc SDLCALL SDL_GetRenderCopyFunc(Uint32 src_format, Uint32 dst_format, int modMode, int blendMode, int scaleMode);

__EOF__
}

sub output_copyfuncname
{
    my $prefix = shift;
    my $src = shift;
    my $dst = shift;
    my $modulate = shift;
    my $blend = shift;
    my $scale = shift;
    my $args = shift;
    my $suffix = shift;

    print FILE "$prefix SDL_RenderCopy_${src}_${dst}";
    if ( $modulate ) {
        print FILE "_Modulate";
    }
    if ( $blend ) {
        print FILE "_Blend";
    }
    if ( $scale ) {
        print FILE "_Scale";
    }
    if ( $args ) {
        print FILE "(SDL_RenderCopyData *data)";
    }
    print FILE "$suffix";
}

sub get_rgba
{
    my $prefix = shift;
    my $format = shift;
    my $string = $get_rgba_string{$format};
    $string =~ s/_/$prefix/g;
    if ( $prefix ne "" ) {
        print FILE <<__EOF__;
            ${prefix}pixel = *$prefix;
__EOF__
    } else {
        print FILE <<__EOF__;
            pixel = *src;
__EOF__
    }
    print FILE <<__EOF__;
            $string
__EOF__
}

sub set_rgba
{
    my $prefix = shift;
    my $format = shift;
    my $string = $set_rgba_string{$format};
    $string =~ s/_/$prefix/g;
    print FILE <<__EOF__;
            $string
            *dst = ${prefix}pixel;
__EOF__
}

sub output_copycore
{
    my $src = shift;
    my $dst = shift;
    my $modulate = shift;
    my $blend = shift;
    if ( $modulate ) {
        print FILE <<__EOF__;
            if (flags & SDL_RENDERCOPY_MODULATE_COLOR) {
                ${src}R = (${src}R * modulateR) / 255;
                ${src}G = (${src}G * modulateG) / 255;
                ${src}B = (${src}B * modulateB) / 255;
            }
__EOF__
    }
    if ( $modulate && $blend ) {
        print FILE <<__EOF__;
            if (flags & SDL_RENDERCOPY_MODULATE_ALPHA) {
                ${src}A = (${src}A * modulateA) / 255;
            }
__EOF__
    }
    if ( $blend ) {
        print FILE <<__EOF__;
            if (flags & (SDL_RENDERCOPY_BLEND|SDL_RENDERCOPY_ADD)) {
                /* This goes away if we ever use premultiplied alpha */
                ${src}R = (${src}R * ${src}A) / 255;
                ${src}G = (${src}G * ${src}A) / 255;
                ${src}B = (${src}B * ${src}A) / 255;
            }
            switch (flags & (SDL_RENDERCOPY_BLEND|SDL_RENDERCOPY_ADD|SDL_RENDERCOPY_MOD)) {
            case SDL_RENDERCOPY_BLEND:
                ${dst}R = ${src}R + ((255 - ${src}A) * ${dst}R) / 255;
                ${dst}G = ${src}G + ((255 - ${src}A) * ${dst}G) / 255;
                ${dst}B = ${src}B + ((255 - ${src}A) * ${dst}B) / 255;
                break;
            case SDL_RENDERCOPY_ADD:
                ${dst}R = ${src}R + ${dst}R; if (${dst}R > 255) ${dst}R = 255;
                ${dst}G = ${src}G + ${dst}G; if (${dst}G > 255) ${dst}G = 255;
                ${dst}B = ${src}B + ${dst}B; if (${dst}B > 255) ${dst}B = 255;
                break;
            case SDL_RENDERCOPY_MOD:
                ${dst}R = (${src}R * ${dst}R) / 255;
                ${dst}G = (${src}G * ${dst}G) / 255;
                ${dst}B = (${src}B * ${dst}B) / 255;
                break;
            }
__EOF__
    }
}

sub output_copyfunc
{
    my $src = shift;
    my $dst = shift;
    my $modulate = shift;
    my $blend = shift;
    my $scale = shift;

    output_copyfuncname("int", $src, $dst, $modulate, $blend, $scale, 1, "\n");
    print FILE <<__EOF__;
{
    const int flags = data->flags;
__EOF__
    if ( $modulate ) {
        print FILE <<__EOF__;
    const Uint32 modulateR = data->r;
    const Uint32 modulateG = data->g;
    const Uint32 modulateB = data->b;
    const Uint32 modulateA = data->a;
__EOF__
    }
    if ( $blend ) {
        print FILE <<__EOF__;
    Uint32 srcpixel;
    Uint32 srcR, srcG, srcB, srcA;
    Uint32 dstpixel;
    Uint32 dstR, dstG, dstB, dstA;
__EOF__
    } elsif ( $modulate || $src ne $dst ) {
        print FILE <<__EOF__;
    Uint32 pixel;
    Uint32 R, G, B, A;
__EOF__
    }
    if ( $scale ) {
        print FILE <<__EOF__;
    int srcy, srcx;
    int posy, posx;
    int incy, incx;

    srcy = 0;
    posy = 0;
    incy = (data->src_h << 16) / data->dst_h;
    incx = (data->src_w << 16) / data->dst_w;

    while (data->dst_h--) {
        $format_type{$src} *src;
        $format_type{$dst} *dst = ($format_type{$dst} *)data->dst;
        int n = data->dst_w;
        srcx = -1;
        posx = 0x10000L;
        while (posy >= 0x10000L) {
            ++srcy;
            posy -= 0x10000L;
        }
        while (n--) {
            if (posx >= 0x10000L) {
                while (posx >= 0x10000L) {
                    ++srcx;
                    posx -= 0x10000L;
                }
                src = ($format_type{$src} *)(data->src + (srcy * data->src_pitch) + (srcx * $format_size{$src}));
__EOF__
        print FILE <<__EOF__;
            }
__EOF__
        if ( $blend ) {
            get_rgba("src", $src);
            get_rgba("dst", $dst);
            output_copycore("src", "dst", $modulate, $blend);
            set_rgba("dst", $dst);
        } elsif ( $modulate || $src ne $dst ) {
            get_rgba("", $src);
            output_copycore("", "", $modulate, $blend);
            set_rgba("", $dst);
        } else {
            print FILE <<__EOF__;
            *dst = *src;
__EOF__
        }
        print FILE <<__EOF__;
            posx += incx;
            ++dst;
        }
        posy += incy;
        data->dst += data->dst_pitch;
    }
__EOF__
    } else {
        print FILE <<__EOF__;

    while (data->dst_h--) {
        $format_type{$src} *src = ($format_type{$src} *)data->src;
        $format_type{$dst} *dst = ($format_type{$dst} *)data->dst;
        int n = data->dst_w;
        while (n--) {
__EOF__
        if ( $blend ) {
            get_rgba("src", $src);
            get_rgba("dst", $dst);
            output_copycore("src", "dst", $modulate, $blend);
            set_rgba("dst", $dst);
        } elsif ( $modulate || $src ne $dst ) {
            get_rgba("", $src);
            output_copycore("", "", $modulate, $blend);
            set_rgba("", $dst);
        } else {
            print FILE <<__EOF__;
            *dst = *src;
__EOF__
        }
        print FILE <<__EOF__;
            ++src;
            ++dst;
        }
        data->src += data->src_pitch;
        data->dst += data->dst_pitch;
    }
__EOF__
    }
    print FILE <<__EOF__;
    return 0;
}

__EOF__
}

sub output_copyfunc_h
{
    my $src = shift;
    my $dst = shift;
    for (my $modulate = 0; $modulate <= 1; ++$modulate) {
        for (my $blend = 0; $blend <= 1; ++$blend) {
            for (my $scale = 0; $scale <= 1; ++$scale) {
                if ( $modulate != 0 || $blend != 0 || $scale != 0 || $src ne $dst ) {
                    output_copyfuncname("extern int SDLCALL", $src, $dst, $modulate, $blend, $scale, 1, ";\n");
                }
            }
        }
    }
}

sub output_copyinc
{
    print FILE <<__EOF__;
#include "SDL_video.h"
#include "SDL_rendercopy.h"

__EOF__
}

sub output_copyfunctable
{
    print FILE <<__EOF__;
static struct {
    Uint32 src_format;
    Uint32 dst_format;
    int modMode;
    int blendMode;
    int scaleMode;
    SDL_RenderCopyFunc func;
} SDL_RenderCopyFuncTable[] = {
__EOF__
    for (my $i = 0; $i <= $#src_formats; ++$i) {
        my $src = $src_formats[$i];
        for (my $j = 0; $j <= $#dst_formats; ++$j) {
            my $dst = $dst_formats[$j];
            for (my $modulate = 0; $modulate <= 1; ++$modulate) {
                for (my $blend = 0; $blend <= 1; ++$blend) {
                    for (my $scale = 0; $scale <= 1; ++$scale) {
                        if ( $modulate != 0 || $blend != 0 || $scale != 0 || $src ne $dst ) {
                            print FILE "    { SDL_PIXELFORMAT_$src, SDL_PIXELFORMAT_$dst, ";
                            if ( $modulate ) {
                                print FILE "(SDL_TEXTUREMODULATE_COLOR | SDL_TEXTUREMODULATE_ALPHA), ";
                            } else {
                                print FILE "0, ";
                            }
                            if ( $blend ) {
                                print FILE "(SDL_TEXTUREBLENDMODE_MASK | SDL_TEXTUREBLENDMODE_BLEND | SDL_TEXTUREBLENDMODE_ADD | SDL_TEXTUREBLENDMODE_MOD), ";
                            } else {
                                print FILE "0, ";
                            }
                            if ( $scale ) {
                                print FILE "SDL_TEXTURESCALEMODE_FAST, ";
                            } else {
                                print FILE "0, ";
                            }
                            output_copyfuncname("", $src_formats[$i], $dst_formats[$j], $modulate, $blend, $scale, 0, " },\n");
                        }
                    }
                }
            }
        }
    }
    print FILE <<__EOF__;
};

SDL_RenderCopyFunc SDL_GetRenderCopyFunc(Uint32 src_format, Uint32 dst_format, int modMode, int blendMode, int scaleMode)
{
    int i;

    for (i = 0; i < SDL_arraysize(SDL_RenderCopyFuncTable); ++i) {
        if (src_format != SDL_RenderCopyFuncTable[i].src_format) {
            continue;
        }
        if (dst_format != SDL_RenderCopyFuncTable[i].dst_format) {
            continue;
        }
        if ((modMode & SDL_RenderCopyFuncTable[i].modMode) != modMode) {
            continue;
        }
        if ((blendMode & SDL_RenderCopyFuncTable[i].blendMode) != blendMode) {
            continue;
        }
        if ((scaleMode & SDL_RenderCopyFuncTable[i].scaleMode) != scaleMode) {
            continue;
        }
        return SDL_RenderCopyFuncTable[i].func;
    }
    return NULL;
}

__EOF__
}

sub output_copyfunc_c
{
    my $src = shift;
    my $dst = shift;

    for (my $modulate = 0; $modulate <= 1; ++$modulate) {
        for (my $blend = 0; $blend <= 1; ++$blend) {
            for (my $scale = 0; $scale <= 1; ++$scale) {
                if ( $modulate != 0 || $blend != 0 || $scale != 0 || $src ne $dst ) {
                    output_copyfunc($src, $dst, $modulate, $blend, $scale);
                }
            }
        }
    }
}

open_file("SDL_rendercopy.h");
output_copydefs();
for (my $i = 0; $i <= $#src_formats; ++$i) {
    for (my $j = 0; $j <= $#dst_formats; ++$j) {
        output_copyfunc_h($src_formats[$i], $dst_formats[$j]);
    }
}
print FILE "\n";
close_file("SDL_rendercopy.h");

open_file("SDL_rendercopy.c");
output_copyinc();
output_copyfunctable();
for (my $i = 0; $i <= $#src_formats; ++$i) {
    for (my $j = 0; $j <= $#dst_formats; ++$j) {
        output_copyfunc_c($src_formats[$i], $dst_formats[$j]);
    }
}
close_file("SDL_rendercopy.c");

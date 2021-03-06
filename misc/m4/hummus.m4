AC_DEFUN([LC_HUMMUS],[
AC_ARG_ENABLE(pdf-renderer,
  AS_HELP_STRING([--enable-pdf-renderer[=yes]],
  [use hummus support for native pdf exports]), [], [unset enableval])

  LC_MSG_CHECKING([hummus support for native pdf exports])
  if @<:@@<:@ "$enableval" != no @:>@@:>@
  then if @<:@@<:@ $CONFIG_GUI != QT @:>@@:>@ 
    then LC_MSG_RESULT([disabled: needs Qt])
    else
      AC_CHECK_HEADER(zlib.h, [
        AC_CHECK_LIB([z],[deflate],[
          if @<:@@<:@ $USE_FREETYPE -eq 3 @:>@@:>@
          then LC_MERGE_FLAGS([-lz],[PDF_LIBS])
            AC_DEFINE(PDF_RENDERER, 1, [Enabling native PDF renderer])
            CONFIG_PDF="Pdf"
            AC_SUBST(CONFIG_PDF)
            LC_SCATTER_FLAGS([-DPDFHUMMUS_NO_TIFF -DPDFHUMMUS_NO_DCT],[PDF])
            LC_COMBINE_FLAGS(PDF)
            LC_MSG_RESULT([enabled])
          else
            LC_MSG_RESULT([disabled: needs freetype >= 2.4.8.])
          fi
        ],[
          LC_MSG_RESULT([disabled: needs libz])
        ])
      ],[
        LC_MSG_RESULT([disabled: needs zlib.h])
      ])
     fi
  else LC_MSG_RESULT([disabled])
  fi
  LC_SUBST(PDF)
])

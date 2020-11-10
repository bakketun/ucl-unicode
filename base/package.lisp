(defpackage #:unicode-base
  (:use :common-lisp)
  (:export
   #:+bmp-code-point-limit+
   #:+code-point-limit+
   #:+first-code-point+
   #:+first-high-surrogate+
   #:+first-low-surrogate+
   #:+last-bmp-code-point+
   #:+last-code-point+
   #:+last-high-surrogate+
   #:+last-low-surrogate+
   #:+object-replacement-character+
   #:+replacement-character+
   #:bmp-code-point
   #:byte-vector-code-unit-string
   #:char-code-unit-string
   #:code-point
   #:code-point-at
   #:code-point-count
   #:code-point-sequence-utf-8-length
   #:code-point-utf-8-encode
   #:code-unit-string
   #:code-unit-string-string
   #:code-unit-string-vector
   #:cuchar
   #:culength
   #:curef
   #:custring
   #:map-code-points
   #:scalar-value
   #:scalar-value-vector
   #:standard-utf-16-string
   #:standard-utf-32-string
   #:standard-utf-8-string
   #:string*
   #:utf-16-code-unit-vector
   #:utf-16-string
   #:utf-32-code-unit-vector
   #:utf-32-string
   #:utf-8-code-unit-vector
   #:utf-8-string
   ))

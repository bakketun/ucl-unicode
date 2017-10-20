(in-package #:unicode)

;; Types

(deftype code-point ()
  '(integer #x0 #x10FFFF))


(deftype unicode-scalar ()
  '(or (integer 0 #xD7FF)
    (integer #xE000 #x10FFFF)))


(deftype utf-8-code-unit () '(unsigned-byte 8))
(deftype utf-16-code-unit () '(unsigned-byte 16))
(deftype utf-32-code-unit () '(unsigned-byte 32))
(deftype string-code-unit () `(integer 0 ,(1- char-code-limit)))

(defgeneric utf-8-p (thing) (:method (thing)))
(deftype utf-8 () '(satisfies utf-8-p))

(defgeneric utf-16-p (thing) (:method (thing)))
(deftype utf-16 () '(satisfies utf-16-p))

(defgeneric utf-32-p (thing) (:method (thing)))
(deftype utf-32 () '(satisfies utf-32-p))

(defun unicodep (object)
  (or (utf-8-p object)
      (utf-16-p object)
      (utf-32-p object)))
(deftype unicode () '(satisfies unicodep))


;; Code unit interface

(defgeneric unicode-length (unicode)
  (:method (thing)
    (error "~S: ~S in not of type unicode." 'unicode-length thing)))

(defgeneric u8ref (unicode index))
(defgeneric u16ref (unicode index))
(defgeneric u32ref (unicode index))

(defgeneric (setf u8ref) (code-unit unicode index))
(defgeneric (setf u16ref) (code-unit unicode index))
(defgeneric (setf u32ref) (code-unit unicode index))

(defun unicode-ref (unicode index)
  (etypecase unicode
    (utf-8 (u8ref unicode index))
    (utf-16 (u16ref unicode index))
    (utf-32 (u32ref unicode index))))

(defun (setf unicode-ref) (code-unit unicode index)
  (etypecase unicode
    (utf-8 (setf (u8ref unicode index) code-unit))
    (utf-16 (setf (u16ref unicode index) code-unit))
    (utf-32 (setf (u32ref unicode index) code-unit))))


;; Code point interface

(defvar *transform-errors-default* :strict)

(defun defaulted-transform-errors (errors)
  (if (member errors '(nil :default))
      *transform-errors-default*
      errors))

(defun replace-when-strict (errors)
  (ecase (defaulted-transform-errors errors)
    (:ignore
     :ignore)
    ((:replace :strict)
     :replace)))

(define-condition unicode-transform-error (error)
  ((unicode :initarg :unicode :reader unicode-transform-error-unicode)
   (control :initarg :control :reader unicode-transform-error-control)
   (arguments :initarg :arguments :reader unicode-transform-error-arguments))
  (:report (lambda (c stream)
             (apply #'format stream
                    (unicode-transform-error-control c)
                    (unicode-transform-error-arguments c)))))

(defgeneric code-point (unicode index &key errors)
  (:method (unicode index &key errors)
    (block nil
      (flet ((transform-error (control &rest arguments)
               (ecase (defaulted-transform-errors errors)
                 ((:replace)
                  (return (values #xFFFD index :replace)))
                 (:ignore
                  (return (values #xFFFD index :ignore)))
                 (:strict
                  (error 'unicode-transform-error :unicode unicode :control control :arguments arguments)))))
        (restart-case
            (etypecase unicode
              (utf-8
               (let ((code-point (u8ref unicode index))
                     (lower #x80)
                     (upper #XBF))
                 (flet ((cbyte ()
                          (unless (< index (unicode-length unicode))
                            (transform-error "End of string in UTF-8 sequence."))
                          (let ((byte (u8ref unicode index)))
                            (unless (<= lower byte upper)
                              (transform-error "Invalid UTF-8 scalar ~X" byte))
                            (setf code-point (logxor (ash code-point 6)
                                                     (ldb (byte 6 0) byte)))
                            (setf lower #x80)
                            (setf upper #xBF)
                            (incf index))))
                   (incf index)
                   (typecase code-point
                     ((integer #x00 #x7F))
                     ((integer #xC2 #xDF)
                      (setf code-point (ldb (byte 6 0) code-point))
                      (cbyte))
                     ((integer #xE0 #xEF)
                      (setf code-point (ldb (byte 5 0) code-point))
                      (when (= #xE0 code-point)
                        (setf lower #xA0))
                      (when (= #xED code-point)
                        (setf upper #x9F))
                      (cbyte)
                      (cbyte))
                     ((integer #xF0 #xF4)
                      (setf code-point (ldb (byte 4 0) code-point))
                      (when (= #xF0 code-point)
                        (setf lower #x90))
                      (when (= #xED code-point)
                        (setf upper #x8F))
                      (cbyte)
                      (cbyte)
                      (cbyte))
                     (t
                      (transform-error "Invalid UTF-8 scalar ~X" code-point))))
                 (values code-point index)))
              (utf-16
               (let ((lead (u16ref unicode index)))
                 (incf index)
                 (cond ((<= #xD800 lead #xDBFF)
                        (unless (< index (unicode-length unicode))
                          (transform-error "End of string in UTF-16 sequence."))
                        (let ((tail (u16ref unicode index)))
                          (unless (<= #xDC00 tail #xDFFF)
                            (transform-error "Invalid UTF-16 tail ~X" tail))
                          (incf index)
                          (values (+ #x10000
                                     (ash (- lead #xD800) 10)
                                     (- tail #xDC00))
                                  index)))
                       (t
                        (when (<= #xDC00 lead #xDFFF)
                          (transform-error "Lone UTF-16 tail surrage ~X" lead))
                        (values lead index)))))
              (utf-32
               (let ((code-point (u32ref unicode index)))
                 (incf index)
                 (unless (typep code-point 'unicode-scalar)
                   (transform-error "Surrogate code point in UTF-32 ~X" code-point))
                 (values code-point index))))
          (replace ()
            :report "Return replacement character U+FFFD."
            (values #xFFFD index 'replace)))))))


(defgeneric set-code-point (unicode index code-point)
  (:method (unicode index code-point)
    (etypecase unicode
      (utf-8
       (cond ((< code-point #x80)
              (setf (u8ref unicode index) code-point)
              (1+ index))
             ((< code-point #x800)
              (setf (u8ref unicode index)
                    (logxor #b11000000 (ldb (byte 5 6) code-point)))
              (setf (u8ref unicode (+ 1 index))
                    (logxor #b10000000 (ldb (byte 6 0) code-point)))
              (+ 2 index))
             ((< code-point #x10000)
              (setf (u8ref unicode index)
                    (logxor #b11100000 (ldb (byte 4 12) code-point)))
              (setf (u8ref unicode (+ 1 index))
                    (logxor #b10000000 (ldb (byte 6 6) code-point)))
              (setf (u8ref unicode (+ 2 index))
                    (logxor #b10000000 (ldb (byte 6 0) code-point)))
              (+ 3 index))
             (t
              (setf (u8ref unicode index)
                    (logxor #b11110000 (ldb (byte 3 18) code-point)))
              (setf (u8ref unicode (+ 1 index))
                    (logxor #b10000000 (ldb (byte 6 12) code-point)))
              (setf (u8ref unicode (+ 2 index))
                    (logxor #b10000000 (ldb (byte 6 6) code-point)))
              (setf (u8ref unicode (+ 3 index))
                    (logxor #b10000000 (ldb (byte 6 0) code-point)))
              (+ 4 index))))
      (utf-16
       (cond ((<= code-point #xFFFF)
              (setf (u16ref unicode index) code-point)
              (1+ index))
             (t
              (setf (u16ref unicode index) (+ #xD7C0 (ldb (byte 10 10) code-point)))
              (setf (u16ref unicode (1+ index)) (+ #xDC00 (ldb (byte 10 0) code-point)))
              (+ 2 index))))
      (utf-32
       (setf (u32ref unicode index) code-point)
       (1+ index)))))

(defun next-code-point (unicode index &key errors)
  (multiple-value-bind (code-point index invalid)
      (code-point unicode index :errors errors)
    (declare (ignore code-point))
    (values index invalid)))

(defun code-point-count (unicode &key errors)
  (loop with errors = (replace-when-strict errors)
        with invalid
        with index = 0
        while (< index (unicode-length unicode))
        do (multiple-value-setq (index invalid) (next-code-point unicode index :errors errors))
        count (not (eq :ignore invalid))))

(defmacro do-code-points ((var unicode &key errors) &body body)
  (let ((%unicode (gensym "UNICODE"))
        (%errors (gensym "ERRORS"))
        (index (gensym "INDEX"))
        (invalid (gensym "INVALID")))
    `(loop with ,var of-type code-point = 0
           with ,%unicode = ,unicode
           with ,%errors = ,errors
           with ,invalid
           with ,index fixnum = 0
           while (< ,index (the fixnum (unicode-length ,%unicode)))
           do (multiple-value-setq (,var ,index ,invalid) (code-point ,%unicode ,index :errors ,%errors))
           unless (eq :ignore ,invalid)
             do (progn ,@body))))

(defun map-code-points (function unicode &key errors)
  (declare (optimize (speed 3))
           (function function))
  (do-code-points (code-point unicode :errors errors)
    (funcall function code-point)))

(defun code-point-utf-8-length (code-point)
  (cond ((< code-point #x80)
         1)
        ((< code-point #x800)
         2)
        ((< code-point #x10000)
         3)
        (t
         4)))

(defun code-point-utf-16-length (code-point)
  (if (<= code-point #xFFFF)
      1
      2))

(defun code-point-length (target code-point)
  (case target
    (utf-8 (code-point-utf-8-length code-point))
    (utf-16 (code-point-utf-16-length code-point))
    (utf-32 1)
    (otherwise
     (code-point-length (nth-value 1 (unicode-constructor target)) code-point))))

(defun utf-8-length (unicode &key errors)
  (let ((length 0))
    (do-code-points (code-point unicode :errors (replace-when-strict errors))
      (incf length (code-point-utf-8-length code-point)))
    length))

(defun utf-16-length (unicode &key errors)
  (let ((length 0))
    (do-code-points (code-point unicode :errors (replace-when-strict errors))
      (incf length (code-point-utf-16-length code-point)))
    length))

(defun utf-32-length (unicode &key errors)
  (code-point-count unicode :errors (replace-when-strict errors)))



(defun unicode-length-for (target source &key errors)
  (case target
    (utf-8 (utf-8-length source :errors errors))
    (utf-16 (utf-16-length source :errors errors))
    (utf-32 (utf-32-length source :errors errors))
    (otherwise
     (unicode-length-for (nth-value 1 (unicode-constructor target)) source :errors errors))))


;; Strings as unicode text

(eval-when (:compile-toplevel :load-toplevel :execute)
  #+force-utf-8-strings (pushnew :utf-8-strings *features*)
  #+force-utf-16-strings (pushnew :utf-16-strings *features*)
  #+force-utf-32-strings (pushnew :utf-32-strings *features*)

  #-(or force-utf-8-strings
        force-utf-16-strings
        force-utf-32-strings)
  (cond ((<= 1114112 char-code-limit)
         (pushnew :utf-32-strings *features*))
        ((= #x10000 char-code-limit)
         (pushnew :utf-16-strings *features*))
        ((<= 256 char-code-limit)
         (pushnew :utf-8-strings *features*))))


;; String as utf-8
#+utf-8-strings
(progn
  (defconstant +string-unicode-type+ 'utf-8)

  (defmethod utf-8-p ((unicode string)) t)

  (defmethod unicode-length ((unicode string))
    (length unicode))

  (defmethod u8ref ((unicode string) index)
    (char-code (char unicode index)))

  (defmethod (setf u8ref) (code-unit (unicode string) index)
    (setf (char unicode index) (code-char code-unit))
    code-unit))


;; String as utf-16
#+utf-16-strings
(progn
  (defconstant +string-unicode-type+ 'utf-16)

  (defmethod utf-16-p ((unicode string)) t)

  (defmethod unicode-length ((unicode string))
    (length unicode))

  (defmethod u16ref ((unicode string) index)
    (char-code (char unicode index)))

  (defmethod (setf u16ref) (code-unit (unicode string) index)
    (setf (char unicode index) (code-char code-unit))
    code-unit))


;; String as utf-32
#+utf-32-strings
(progn
  (defconstant +string-unicode-type+ 'utf-32)

  (defmethod utf-32-p ((unicode string)) t)

  (defmethod unicode-length ((unicode string))
    (length unicode))

  (defmethod u32ref ((unicode string) index)
    (char-code (char unicode index)))

  (defmethod (setf u32ref) (code-unit (unicode string) index)
    (setf (char unicode index) (code-char code-unit))
    code-unit))


;; utf-8 unicode

(defstruct %utf-8
  (data nil :type (vector utf-8-code-unit)))

(defmethod make-load-form ((unicode %utf-8) &optional environment)
  (declare (ignore environment))
  `(make-%utf-8 :data ,(%utf-8-data unicode)))

(defun make-utf-8 (count)
  (make-%utf-8 :data (make-array count :element-type 'utf-8-code-unit)))

(defmethod utf-8-p ((unicode %utf-8)) t)

(defmethod unicode-length ((unicode %utf-8))
  (length (%utf-8-data unicode)))

(defmethod u8ref ((unicode %utf-8) index)
  (aref (%utf-8-data unicode) index))

(defmethod (setf u8ref) (code-unit (unicode %utf-8) index)
  (setf (aref (%utf-8-data unicode) index) code-unit))


;; utf-16 unicode

(defstruct %utf-16
  (data nil :type (vector utf-16-code-unit)))

(defmethod make-load-form ((unicode %utf-16) &optional environment)
  (declare (ignore environment))
  `(make-%utf-16 :data ,(%utf-16-data unicode)))

(defun make-utf-16 (count)
  (make-%utf-16 :data (make-array count :element-type 'utf-16-code-unit)))

(defmethod utf-16-p ((unicode %utf-16)) t)

(defmethod unicode-length ((unicode %utf-16))
  (length (%utf-16-data unicode)))

(defmethod u16ref ((unicode %utf-16) index)
  (aref (%utf-16-data unicode) index))

(defmethod (setf u16ref) (code-unit (unicode %utf-16) index)
  (setf (aref (%utf-16-data unicode) index) code-unit))


;; utf-32 unicode

(defstruct %utf-32
  (data nil :type (vector utf-32-code-unit)))

(defmethod make-load-form ((unicode %utf-32) &optional environment)
  (declare (ignore environment))
  `(make-%utf-32 :data ,(%utf-32-data unicode)))

(defun make-utf-32 (count)
  (make-%utf-32 :data (make-array count :element-type 'utf-32-code-unit)))

(defmethod utf-32-p ((unicode %utf-32)) t)

(defmethod unicode-length ((unicode %utf-32))
  (length (%utf-32-data unicode)))

(defmethod u32ref ((unicode %utf-32) index)
  (aref (%utf-32-data unicode) index))

(defmethod (setf u32ref) (code-unit (unicode %utf-32) index)
  (setf (aref (%utf-32-data unicode) index) code-unit))

;; unicode constructors

(defun unicode-constructor (format)
  (etypecase format
    (string (values #'make-string +string-unicode-type+))
    (utf-8 (values #'make-utf-8 'utf-8))
    (utf-16 (values #'make-utf-16 'utf-16))
    (utf-32 (values #'make-utf-32 'utf-32))
    (symbol
     (ecase format
       (string (values #'make-string +string-unicode-type+))
       (utf-8 (values #'make-utf-8 'utf-8))
       (utf-16 (values #'make-utf-16 'utf-16))
       (utf-32 (values #'make-utf-32 'utf-32))))))

(defvar *default-unicode-format* 'string)

(defun make-unicode (count &key format)
  (funcall (unicode-constructor (or format *default-unicode-format*)) count))

(defun unicode (thing)
  (if (unicodep thing)
      thing
      (unicode* thing)))

(defun utf-8 (thing)
  (if (utf-8-p thing)
      thing
      (utf-8* thing)))

(defun utf-16 (thing)
  (if (utf-16-p thing)
      thing
      (utf-16* thing)))

(defun utf-32 (thing)
  (if (utf-32-p thing)
      thing
      (utf-32* thing)))

(defun unicode-string (thing)
  (if (stringp thing)
      thing
      (unicode-string* thing)))

(defun unicode* (&rest data)
  (unicode** data))

(defun unicode** (data &optional format)
  (multiple-value-bind (constructor format)
      (unicode-constructor (or format *default-unicode-format*))
    (unless (listp data)
      (setf data (list data)))
    (let* ((length (loop with errors = nil
                         for elt in data
                         summing (etypecase elt
                                   (keyword
                                    (setf errors elt)
                                    0)
                                   (unicode
                                    (unicode-length-for format elt :errors errors))
                                   (character
                                    (unicode-length-for format (string elt) :errors errors))
                                   (integer
                                    1))))
           (unicode (funcall constructor length)))
      (loop with errors = nil
            with index = 0
            for elt in data
            do (etypecase elt
                 (keyword
                  (setf errors elt))
                 (unicode
                  (do-code-points (code-point elt :errors errors)
                    (setf index (set-code-point unicode index code-point))))
                 (character
                  (do-code-points (code-point (string elt) :errors errors)
                    (setf index (set-code-point unicode index code-point))))
                 (integer
                  (setf (unicode-ref unicode index) elt)
                  (incf index))))
      unicode)))

(defun utf-8* (&rest data)
  (unicode** data 'utf-8))

(defun utf-16* (&rest data)
  (unicode** data 'utf-16))

(defun utf-32* (&rest data)
  (unicode** data 'utf-32))

(defun unicode-string* (&rest data)
  (unicode** data 'string))


;; printing unicode readable


(defun print-unicode-code-units (stream type code-units digits)
  (format stream "#~Au(" (case type
                           (utf-8 8)
                           (utf-16 16)
                           (utf-32 32)))
  (loop for byte across code-units
        for first = t then nil
        do (unless first (princ " " stream))
        do (format stream "#x~v,'0X" digits byte))
  (princ ")" stream))

(defmethod print-object ((unicode %utf-8) stream)
  (print-unicode-code-units stream 'utf-8 (%utf-8-data unicode) 2))

(defmethod print-object ((unicode %utf-16) stream)
  (print-unicode-code-units stream 'utf-16 (%utf-16-data unicode) 4))

(defmethod print-object ((unicode %utf-32) stream)
  (print-unicode-code-units stream 'utf-32 (%utf-32-data unicode) 4))

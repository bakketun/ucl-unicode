(defpackage #:unicode-user
  (:use :common-lisp :unicode))

(in-package #:unicode-user)

#.(enable-unicode-text-syntax)

(list #u"hei")
(copy-text "hei")

#16U+FFFF
(utf-16 #32u<FFFF>)


#U+1f4a9
#8U+1f4a9
(list #8u"hello world…")

(utf-32 "hello world…")

(code-point-at "hello world" 1)

(code-point-count "hello")

(utf-16 "hello💩")

(code-point-count "💩a…💩")

(code-point-count (utf-16 "💩a…💩"))

(text-string (utf-16 "💩a…💩"))

(code-point-at "h" 0)

(utf-8 "💩a…💩")

(text-string (utf-8 (utf-32 (utf-16 (utf-8 (utf-16 "blåbærsyltetøy"))))))

#+sbcl
(sb-ext:octets-to-string (unicode::%utf-8-data (utf-8 (utf-32 (utf-16 (utf-8 (utf-16 "blåbærsyltetøy")))))))

#8U+00A2
#8U+20AC
#8U+10348

(utf-32 #8u+0430)
(utf-32 #8u+4E8C)
(utf-32 #8u+10302)

(defun print-hello ()
  (print (text-string #8u"hello world…")))

;;(print-hello)

;;(code-point-count (utf-8 #xff #x41))
;;(code-point-count (utf-8 #xff #x41) :errors :replace)
;;(code-point-count (utf-8 #xff #x41) :errors :ignore)

(let ((unicode::*transform-errors-default* :ignore))
  (utf-16 #8u<ff 41>))

;;(utf-16 :ignore (utf-8 #xff #x41))

;;(code-point-count (utf-8 #xff #x41) :errors :replace)

;;(utf-16 :replace (utf-8 #xff #x41) (utf-8 #xff #x41))

(concatenate-text (list "string" #U+0042 "string" #U+16222))

(utf-8 (utf-8 "hello"))


(list #16u({pile of poo} {greek_capital_letter_delta}))

#u{GREEK_CAPITAL_LETTER_DELTA}

(code-point-at (concatenate-text (list #u{PILE OF POO} "a" #u{PILE OF POO} "a") :type 'utf-8 :errors :ignore) 4)
(code-point-before (concatenate-text (list #u{PILE OF POO} "a" #u{PILE OF POO} "a")) 4)
;;(code-point-at (utf-8 "aaa" #xf0 #x90 "bbb") 3)
(code-point-before (concatenate-text (list "aaa" #8u<f0 90> "bbb") :type 'utf-8) 5 :errors :ignore)

(code-point-at #16u({PILE OF POO} "a" {PILE OF POO} "a") 3)
(code-point-before #16u({PILE OF POO} "a" {PILE OF POO} "a") 5)
(u16ref #16u({PILE OF POO} "a" {PILE OF POO} "a") 3)


(utf-8 #\PILE_OF_POO)
(text #\PILE_OF_POO)
(text-string #\PILE_OF_POO)

;;(let ((not-used)) (text "stuff")) ;; function text is called with NIL during compile-file. Why?

(let ((*default-text-type* 'utf-8))
  (text #U+00ff))

(utf-16 #8u<ff> :errors :replace)

(concatenate-text (list #8u<F0 9F> #8u<92 A9>) :type 'string)

(concatenate-text (list #8u<F0 9F> "a" #8u<92 A9>) :type 'string :errors :replace)

;;(copy-text "hello" :type (utf-16 ""))

(concatenate-text (list #8u<F0 9F> #8u<92 A9>))
(concatenate-text (list #8u<F0 9F> #8u<92 A9>) :type 'utf-16)
(concatenate-text (list "A " #8u<F0 9F> #8u<92 A9>))



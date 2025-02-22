(local fennel (require :fennel))
(local fish   (require :fishlib))

(local stdlib "
{ swap drop } :nip
{ swap dup rot swap dup rot } :2dup
{ swap dup rot } :over
")

(fn nested-insert [t depth value]
  (var t t)
  (for [i 1 (- depth 1)]
    (set t (. t (length t))))
  (table.insert t value))

(fn remove-nested [t depth]
  (var t t)
  (for [i 1 (- depth 1)]
    (set t (. t (length t))))
  (table.remove t))

(fn insert-first [t value]
  (var result [value])
  (each [_ v (ipairs t)]
    (table.insert result v))
  result)

(fn parse [str]
  (var str (.. str " "))
  (var i 0)
  (var ast (fennel.list (fennel.sym "fish.hcat")))
  (var state :normal)
  (var word "")
  (var depth 1)
  (var dictionary {})
  (while (<= i (length str))
    (set i (+ 1 i))
    (let [char (string.sub str i i)]
      (if
        (and
          (string.match char "%s")
          (= :include state))
        (do
          (if (= :stdlib word)
            (set str (.. (str:sub 1 i)
                         " " stdlib " "
                         (str:sub (+ 1 i))))
            (let [(file message) (io.open (.. word ".🐟"))]
              (when message (error message))
              (set str (.. (str:sub 1 i)
                           " " (file:read :a*) " "
                           (str:sub (+ 1 i))))))
          (set state :normal)
          (set word ""))

        ;; end of a word
        (and
          (string.match char "%s")
          (= :normal state))
        (do
          (nested-insert ast depth
            (if
              (= "" word)
              nil

              (. dictionary word)
              (. dictionary word)

              (tonumber word)
              (fennel.list (fennel.sym "fish.int") (tonumber word))

              (= :INCLUDE: word)
              (set state :include)

              (= "{" word)
              (do
                (set depth (+ depth 1))
                (fennel.list (fennel.sym "fish.hcat")))

              (= "}" word)
              (set depth (- depth 1))

              (= :when word)
              (let [last (remove-nested ast depth)]
                (fennel.list (fennel.sym "fish.when") last))

              (= :unless word)
              (let [last (remove-nested ast depth)]
                (fennel.list (fennel.sym "fish.unless") last))

              (= :if word)
              (let [else (remove-nested ast depth)
                    then (remove-nested ast depth)]
                (fennel.list (fennel.sym "fish.if") then else))

              (= :while word)
              (let [last (remove-nested ast depth)]
                (fennel.list (fennel.sym "fish.while") last))

              (= :until word)
              (let [last (remove-nested ast depth)]
                (fennel.list (fennel.sym "fish.until") last))

              (. fish.ops word)
              (fennel.list (fennel.sym ".") (fennel.sym "fish.ops") word)

              (and (= ":" (word:sub 1 1))
                (> (length word) 1))
              (let [last (remove-nested ast depth)]
                (tset dictionary (word:sub 2) last)
                nil)

              (error (.. "unknown word: " word))))
          ;(set state :normal)
          (set word ""))

        ;; start of a printed string
        (and
          (= char "\"")
          (= :normal state))
        (set state :print)

        ;; end of a printed string
        (and
          (= char "\"")
          (= :print state))
        (do
          (nested-insert ast depth
            (fennel.list
              (fennel.sym "fish.print")
              (-> word
                (string.gsub "\\n" "\n")
                (string.gsub "\\\"" "\"")
                (.. ""))))
          (set word "")
          (set state :normal))

          ;; start of a string
        (and
          (= char "'")
          (= :normal state))
        (set state :string)

        ;; end of a string
        (and
          (= char "'")
          (= :string state))
        (do
          (nested-insert ast depth
            (fennel.list
              (fennel.sym "fish.string")
              (-> word
                (string.gsub "\\n" "\n")
                (string.gsub "\\'" "'")
                (.. ""))))
          (set word "")
          (set state :normal))

        ;; start of a comment
        (and
          (= :# char)
          (= :normal state))
        (set state :comment)

        ;; end of a comment
        (and
          (= "\n" char)
          (= :comment state))
        (set state :normal)

        ;; else
        (not= :comment state)
        (set word (.. word char)))))
  ;; insert end
  (when (not= :end (. ast (length ast) 3))
    (table.insert
      ast
      (fennel.list (fennel.sym ".") (fennel.sym "fish.ops") :end)))
  (tostring ast))

(fennel.eval
  (..
    "(local fish (require :fishlib))\n"
    "(print "
    (parse (: (io.open (. arg 1)) :read :a*))
    ")"))

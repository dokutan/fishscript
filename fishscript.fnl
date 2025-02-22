(local fennel (require :fennel))
(local fish   (require :fishlib))

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
  (var ast (fennel.list (fennel.sym "fish.hcat")))
  (var state :normal)
  (var word "")
  (var depth 1)
  (let [str (.. str " ")]
    (for [i 1 (length str)]
      (let [char (string.sub str i i)]
        (if
          ;; end of a word
          (and
            (string.match char "%s")
            (= :normal state))
          (do
            (nested-insert ast depth
              (if
                (= "" word)
                nil

                (tonumber word)
                (fennel.list (fennel.sym "fish.int") (tonumber word))

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

                (error (.. "unknown word: " word))))
            (set state :normal)
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

          ;; start of a comment
          (and
            (= "\n" char)
            (= :comment state))
          (set state :normal)

          ;; else
          (not= :comment state)
          (set word (.. word char))))))
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

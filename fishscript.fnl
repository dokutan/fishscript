(local fennel (require :fennel))
(local fish   (require :fishlib))

(local stdlib "
{ swap drop } :nip
{ swap dup rot swap dup rot } :2dup
{ swap dup rot } :over
{ rot rot swap } :swapd
{ 2dup % swapd - swap / } :div
div :÷
{ 0 = } :not
{ = not } :!=
{ < not } :>=
{ > not } :<=
{ [ left dup right ] } :nth
{ 1 + [ left drop right ] } :set-nth
{ dup 0 < 2 * 1 swap - * } :abs
{ dup 1 % - } :floor
{ < 1 + nth } :min
{ > 1 + nth } :max
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
  (var variables  {})
  (var variable-pos 0)
  (while (<= i (length str))
    (set i (+ 1 i))
    (let [char      (string.sub str i i)
          two-chars (string.sub str i (+ 1 i))]
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

              (= :cond word)
              (let [clauses     (remove-nested ast depth)
                    clauses-seq []]
                (for [i 2 (length clauses)]
                  (table.insert clauses-seq (. clauses i)))
                (fennel.list (fennel.sym "fish.cond") clauses-seq))

              (= :loop word)
              (let [last (remove-nested ast depth)]
                (fennel.list (fennel.sym "fish.loop") last))

              (= :while word)
              (let [last (remove-nested ast depth)]
                (fennel.list (fennel.sym "fish.while") last))

              (= :while* word)
              (let [block     (remove-nested ast depth)
                    condition (remove-nested ast depth)]
                (fennel.list (fennel.sym "fish.while*") condition block))

              (= :until word)
              (let [last (remove-nested ast depth)]
                (fennel.list (fennel.sym "fish.until") last))

              (. fish.ops word)
              (fennel.list (fennel.sym ".") (fennel.sym "fish.ops") word)

              (and (= "=" (word:sub 1 1))
                (> (length word) 1))
              (do
                (when (not (. variables (word:sub 2)))
                  (tset variables (word:sub 2) variable-pos)
                  (set variable-pos (+ 1 variable-pos)))
                (fennel.list (fennel.sym "fish.put") (. variables (word:sub 2)) -1))

              (. variables word)
              (fennel.list (fennel.sym "fish.get") (. variables word) -1)

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
          (= :print state)
          (or (=    "\\\\" (word:sub (- (length word) 1)))
              (not= "\\"   (word:sub (length word)))))
        (do
          (nested-insert ast depth
            (fennel.list
              (fennel.sym "fish.print")
              (-> word
                (string.gsub "\\n" "\n")
                (string.gsub "\\\"" "\"")
                (string.gsub "\\\\" "\\")
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
          (= :string state)
          (or (=    "\\\\" (word:sub (- (length word) 1)))
              (not= "\\"   (word:sub (length word)))))
        (do
          (nested-insert ast depth
            (fennel.list
              (fennel.sym "fish.string")
              (-> word
                (string.gsub "\\n" "\n")
                (string.gsub "\\'" "'")
                (string.gsub "\\\\" "\\")
                (.. ""))))
          (set word "")
          (set state :normal))

        ;; start of a fish block
        (and
          (= two-chars "«")
          (= :normal state))
        (do
          (set i (+ 1 i))
          (set state :fish))

        ;; end of a fish block
        (and
          (= two-chars "»")
          (= :fish state))
        (let [out (. (remove-nested ast depth) 2)
              in  (. (remove-nested ast depth) 2)]
          (nested-insert ast depth
            (fennel.list
              (fennel.sym "fish.block")
              (icollect [line (word:gmatch "([^\n]*)\n?")] line)
              :left  in
              :right out))
          (set i (+ 1 i))
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

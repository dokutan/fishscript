(local fish {})

;; utils
(fn reverse [str]
  "Reverse `str`"
  (accumulate [result ""
               _ c (utf8.codes str)]
    (.. (utf8.char c) result)))

(fn map [f list]
  (icollect [_ v (ipairs list)] (f v)))

(fn fold [f initial list]
  (accumulate [result initial
                _ v (ipairs list)]
    (f result v)))

(fn list-max [list]
  (fold math.max 0 list))

(fn list-min [list]
  (fold math.min 0 list))

(fn fish.pprint [block]
  "Pretty print `block`"
  (..
    ;; header
    "\x1b[46m "
    (faccumulate [r "" i 1 (block:x)]
      (..
        r
        (if
          (and
            (= :up block.in-edge)
            (= i block.in-pos))
          "i"
          (and
            (= :up block.out-edge)
            (= i block.out-pos))
          "o"
          " ")))
    " \x1b[0m\n"
    ;; block
    (faccumulate [r "" i 1 (block:y)]
      (..
        r
        "\x1b[46m"
        (if
          (and
            (= :left block.in-edge)
            (= i block.in-pos))
          "i"
          (and
            (= :left block.out-edge)
            (= i block.out-pos))
          "o"
          " ")
        "\x1b[47m"
        (. block :code i)
        "\x1b[46m"
        (if
          (and
            (= :right block.in-edge)
            (= i block.in-pos))
          "i"
          (and
            (= :right block.out-edge)
            (= i block.out-pos))
          "o"
          " ")
        "\x1b[0m\n"))
    ;; footer
    "\x1b[46m "
    (faccumulate [r "" i 1 (block:x)]
      (..
        r
        (if
          (and
            (= :down block.in-edge)
            (= i block.in-pos))
          "i"
          (and
            (= :down block.out-edge)
            (= i block.out-pos))
          "o"
          " ")))
    " \x1b[0m"))

;; block constructors
(fn fish.block [code in-edge in-pos out-edge out-pos]
  "Construct a block."
  (let [meta
        {:__tostring #(table.concat (. $ :code) "\n")}
        block
        {:code (if (= :table (type code))
                code
                [code])
        : in-edge
        : in-pos
        : out-edge
        : out-pos
        :x #(utf8.len (. $ :code 1))
        :y #(length (. $ :code))}]
    (setmetatable block meta)
    block))

(fn fish.line [code]
  "Construct a block from a single line."
  (fish.block [code] :left 1 :right 1))

;; block composition and reshaping
(fn fish.right|left [a b]
  "Concatenate `a` (out-edge :right) and `b` (in-edge :left)"
  (assert (= :right a.out-edge))
  (assert (= :left  b.in-edge))
  (var code [])
  (var no-glue? (= b.in-pos a.out-pos))
  (for [i 1 (math.max (a:y) (b:y))]
    (table.insert
      code
      (..
        (if (< (a:y) i)
          (string.rep " " (a:x))
          (. a :code i))
        (if
          no-glue?
          ""
          (< i b.in-pos) "v"
          (= i b.in-pos) ">"
          (> i b.in-pos) "^")
        (if (< (b:y) i)
          (string.rep " " (b:x))
          (. b :code i)))))
  (fish.block
    code
    a.in-edge
    a.in-pos
    b.out-edge
    (case b.out-edge
      :up   (+ (if no-glue? 0 1) (a:x) b.out-pos)
      :down (+ (if no-glue? 0 1) (a:x) b.out-pos)
      _     b.out-pos)))

(fn fish.hcat [...]
  (accumulate [result (fish.line "")
               _ block (ipairs [...])]
    (fish.right|left result block)))

(fn fish.>right [block]
  "Change out-edge to :right"
  (case block.out-edge
    :right block
    :down
    (do
      (var code [])
      (for [i 1 (block:y)]
        (table.insert code (. block :code i)))
      (table.insert code (string.rep ">" (block:x)))
      (fish.block code block.in-edge block.in-pos :right (+ 1 (block:y))))
    :up
    (do
      (var code [(string.rep ">" (block:x))])
      (for [i 1 (block:y)]
        (table.insert code (. block :code i)))
      (fish.block
        code
        block.in-edge
        (if (= :left block.in-edge)
          (+ 1 block.in-pos)
          block.in-pos)
        :right
        1))
    :left (error "not implemented")))

(fn fish.>left [block]
  "Change out-edge to :left"
  (case block.out-edge
    :left block
    :down
    (do
      (var code [])
      (for [i 1 (block:y)]
        (table.insert code (. block :code i)))
      (table.insert code (string.rep "<" (block:x)))
      (fish.block code block.in-edge block.in-pos :left (+ 1 (block:y))))
    :up
    (do
      (var code [(string.rep "<" (block:x))])
      (for [i 1 (block:y)]
        (table.insert code (. block :code i)))
      (fish.block
        code
        block.in-edge
        (if (= :right block.in-edge)
          (+ 1 block.in-pos)
          block.in-pos)
        :left
        1))
    :right (error "not implemented")))

(fn fish.>up [block]
  "Change out-edge to :up"
  (case block.out-edge
    :right
    (do
      (var code [])
      (for [i 1 (block:y)]
        (table.insert code (.. (. block :code i) "^")))
      (fish.block code block.in-edge block.in-pos :up (+ 1 (block:x))))
    :down (error "not implemented")
    :up block
    :left
    (do
      (var code [])
      (for [i 1 (block:y)]
        (table.insert code (.. "^" (. block :code i))))
      (fish.block code block.in-edge block.in-pos :up 1))))

(fn fish.>down [block]
  "Change out-edge to :down"
  (case block.out-edge
    :right
    (do
      (var code [])
      (for [i 1 (block:y)]
        (table.insert code (.. (. block :code i) "v")))
      (fish.block code block.in-edge block.in-pos :down (+ 1 (block:x))))
    :up (error "not implemented")
    :down block
    :left
    (do
      (var code [])
      (for [i 1 (block:y)]
        (table.insert code (.. "v" (. block :code i))))
      (fish.block code block.in-edge (+ 1 block.in-pos) :down 1))))

(fn fish.left> [block]
  "Change in-edge to :left"
  (case block.in-edge
    :left block
    :down
    (do
      (var code [])
      (for [i 1 (block:y)]
        (table.insert
          code (. block :code i)))
      (table.insert
        code
        (faccumulate [r "" i 1 (block:x)]
          (.. r
            (if
              (< i block.in-pos) ">"
              (= i block.in-pos) "^"
              (> i block.in-pos) " "))))
      (fish.block code :left [(+ 1 (block:y))] block.out-edge block.out-pos))
    :up
    (do
      (var code [])
      (table.insert
        code
        (faccumulate [r "" i 1 (block:x)]
          (.. r
            (if
              (< i block.in-pos) ">"
              (= i block.in-pos) "v"
              (> i block.in-pos) " "))))
      (for [i 1 (block:y)]
        (table.insert
          code (. block :code i)))
      (fish.block code :left 1 block.out-edge
        (if (= :right block.out-edge)
          block.out-pos
          (+ 1 block.out-pos))))
    :right (error "not implemented")))

(fn fish.left-to-right-1-1 [block]
  "Change in-edge to :left, in-pos to 1, out-edge to :right and out-pos to 1"
  (let [block (-> block fish.left> fish.>right)]
    (if (= 1 block.in-pos block.out-pos)
      block
      (fish.block
        (icollect [i line (ipairs block.code)]
          (..
            (if
              (= 1 block.in-pos) ""
              (= i block.in-pos) ">"
              (= 1 i)            "v"
                                 " ")
            line
            (if
              (= 1 block.out-pos) ""
              (= i block.out-pos) "^"
              (= 1 i)             ">"
                                  " ")))
        :left 1 :right 1))))

;; control flow
(fn fish.generic-loop [start end left-in left right-out right]
  ""
  (assert (= (length start) (length left-in) (length left)))
  (assert (= (length end) (length right-out) (length right)))
  (fn [block]
    (let [block (-> block fish.left> fish.>right)
          code [(.. start (string.rep " " (block:x)) end)]]
      (for [i 1 (block:y)]
          (table.insert
            code
            (..
              (if (= i block.in-pos)
                left-in
                left)
              (. block :code i)
              (if (= i block.out-pos)
                right-out
                right))))
      (fish.block code :left 1 :right 1))))

(set fish.when (fish.generic-loop "?v" ">" " >" "  " "^" " "))
(set fish.unless (fish.generic-loop "?!v" ">" "  >" "   " "^" " "))
(set fish.loop (fish.generic-loop "v" "<" ">" " " "^" " "))
(set fish.while (fish.generic-loop "v" " <>" ">" " " "?^^" "   "))
(set fish.until (fish.generic-loop "v" "  <>" ">" " " "?!^^" "    "))

(fn fish.if [then else]
  (let [then (-> then fish.left> fish.>right)
        else (-> else fish.left> fish.>right)
        collapse-else (= 1 else.in-pos else.out-pos)
        code (if collapse-else
          [(.. "?v" (. else :code 1) (string.rep " " (- (then:x) (else:x))) ">")]
          [(.. "?vv" (string.rep " " (math.max (else:x) (then:x))) ">")])]
    (for [i (if collapse-else 2 1) (else:y)]
        (table.insert
          code
          (..
            (if collapse-else " " "  ")
            (if (= i else.in-pos)
              ">"
              " ")
            (. else :code i)
            (string.rep " " (- (then:x) (else:x)))
            (if (= i else.out-pos)
              "^"
              " "))))
    (for [i 1 (then:y)]
        (table.insert
          code
          (..
            " "
            (if (= i then.in-pos)
              ">"
              " ")
            (if collapse-else "" " ")
            (. then :code i)
            (string.rep " " (- (else:x) (then:x)))
            (if (= i then.out-pos)
              "^"
              " "))))
    (fish.block code :left 1 :right 1)))

(fn fish.cond [clauses]
  (assert (>= (length clauses) 2)      "cond requires at least two arguments")
  (assert (= 0 (% (length clauses) 2)) "cond requires an even number of arguments")
  (let [clauses (map fish.left-to-right-1-1 clauses)

        conditions
        (fcollect [i 1 (length clauses) 2]
          (fish.block
            (fcollect [j 1 (+ 1 (: (. clauses i) :y))]
              (if (<= j (: (. clauses i) :y))
                  (..
                    (if (= 1 j) ">" " ")
                    (. clauses i :code j)
                    (if (= 1 j) "?!v" "   "))
                  (..
                    "v"
                    (string.rep " " (: (. clauses i) :x))
                    "  <")))
            :left 1 :right 1))

        bodies
        (fcollect [i 2 (length clauses) 2]
          (. clauses i))

        merged-pairs
        (fcollect [i 1 (length conditions)]
          (fish.hcat (. conditions i) (. bodies i)))

        width (list-max (map #(: $1 :x) merged-pairs))

        code []]
    (each [j pair (ipairs merged-pairs)]
      (for [i 1 (pair:y)]
        (table.insert
          code
          (..
            (. pair :code i)
            (string.rep " " (- width (pair:x)))
            (if (= i j 1) ">" (= 1 i) "^" " ")))))
    (table.insert code (.. ">" (string.rep " " (- width 1)) "^"))
    (fish.block code :left 1 :right 1)))

(fn fish.while* [condition block]
  (let [condition (-> condition fish.left> fish.>right)
        block     (-> block     fish.left> fish.>right)
        code      []]
    (for [i 1 (condition:y)]
        (table.insert
          code
          (..
            (if
              (= i condition.in-pos) ">"
              (> i condition.in-pos) "^"
              " ")
            (. condition :code i)
            (if (= i condition.out-pos)
              "?v"
              "  ")
            (string.rep " " (+ 1 (block:x))))))
    (table.insert
      code
      (.. "^" (string.rep " " (+ 2 (condition:x) (block:x))) "<"))
    (for [i 1 (block:y)]
        (table.insert
          code
          (..
            (string.rep " " (+ 2 (condition:x)))
            (if (= i block.in-pos)
              ">"
              " ")
            (. block :code i)
            (if (= i block.out-pos)
              "^"
              " "))))
    (fish.block code :left condition.in-pos :right condition.out-pos)))

(fn fish.string [str]
  "Push `str`"
  (fish.line
    (string.gsub
      (..
        "'"
        (reverse
          (-> str
            (string.gsub "'" "'\"'\"'")
            (string.gsub "\n" "'a'")))
        "'")
      "''" "")))

(fn fish.print [str]
  "Print `str`"
  (fish.hcat
    (fish.string str)
    (fish.line (string.rep "o" (utf8.len str)))))

(fn fish.int [i]
  "Push `i`"
  (if
    (< 9 i 16)            (fish.line (string.char (+ i 87)))
    (= 39 i)              (fish.line "\"'\"")
    (< 31 i 127)          (fish.line (.. "'" (string.char i) "'"))
    (< 0xa1 i 0xd800)     (fish.line (.. "'" (utf8.char i) "'"))
    (< 0xdfff i 0x110000) (fish.line (.. "'" (utf8.char i) "'"))
    (let [n (tostring (math.abs i))]
      (fish.line
        (..
          (if (< i 0) "0" "")
          (n:reverse)
          (string.rep "a*+" (- (length n) 1))
          (if (< i 0) "-" ""))))))

(fn fish.put [x y]
  "Pop a value and put it at `x`,`y` in the code."
  (fish.hcat
    (fish.int x)
    (fish.int y)
    (fish.line "p")))

(fn fish.get [x y]
  "Push the character at `x`,`y` in the code."
  (fish.hcat
    (fish.int x)
    (fish.int y)
    (fish.line "g")))

;; ><> instructions as blocks
(set fish.ops
  {"+" (fish.line "+")
   "-" (fish.line "-")
   "*" (fish.line "*")
   "/" (fish.line ",")
   "%" (fish.line "%")
   "=" (fish.line "=")
   ">" (fish.line ")")
   "<" (fish.line "(")
   "dup" (fish.line ":")
   "drop" (fish.line "~")
   "rot" (fish.line "@")
   "swap" (fish.line "$")
   "left" (fish.line "{")
   "right" (fish.line "}")
   "reverse" (fish.line "r")
   "length" (fish.line "l")
   "end" (fish.line ";")
   "&" (fish.line "&")
   "[" (fish.line "[")
   "]" (fish.line "]")
   "i" (fish.line "i")
   "o" (fish.line "o")
   "n" (fish.line "n")})

fish

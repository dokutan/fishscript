(local fish {})

;; utils
(fn contains? [list value]
  "Check if `list` contains `value`."
  (var result false)
  (each [_ v (ipairs list)]
    (when (= v value)
      (set result true)))
  result)

(fn ++ [i list]
  "Add `i` to every element in `list`"
  (icollect [_ l (ipairs list)]
    (+ i l)))

(fn reverse [str]
  "Reverse `str`"
  (accumulate [result ""
               _ c (utf8.codes str)]
    (.. (utf8.char c) result)))

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
            (contains? block.in-pos i))
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
            (contains? block.in-pos i))
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
            (contains? block.in-pos i))
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
            (contains? block.in-pos i))
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
  (fish.block [code] :left [1] :right 1))

;; block composition and reshaping
(fn fish.right|left [a b]
  "Concatenate `a` (out-edge :right) and `b` (in-edge :left)"
  (assert (= :right a.out-edge))
  (assert (= :left  b.in-edge))
  (var code [])
  (var no-glue?
    (and
      (= 1 (length b.in-pos))
      (= (. b :in-pos 1)
          a.out-pos)))
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
          (< i (. b :in-pos 1)) "v"
          (= i (. b :in-pos 1)) ">"
          (> i (. b :in-pos 1)) "^")
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
          (++ 1 block.in-pos)
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
          (++ 1 block.in-pos)
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
      (fish.block code block.in-edge (++ 1 block.in-pos) :down 1))))

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
              (< i (. block :in-pos 1)) ">"
              (= i (. block :in-pos 1)) "^"
              (> i (. block :in-pos 1)) " "))))
      (fish.block code :left [(+ 1 (block:y))] block.out-edge block.out-pos))
    :up
    (do
      (var code [])
      (table.insert
        code
        (faccumulate [r "" i 1 (block:x)]
          (.. r
            (if
              (< i (. block :in-pos 1)) ">"
              (= i (. block :in-pos 1)) "v"
              (= i (. block :in-pos 1)) " "))))
      (for [i 1 (block:y)]
        (table.insert
          code (. block :code i)))
      (fish.block code :left [1] block.out-edge
        (if (= :right block.out-edge)
          block.out-pos
          (+ 1 block.out-pos))))
    :right (error "not implemented")))

;; control flow
(fn fish.when [block]
  (let [block (-> block fish.left> fish.>right)
        code [(.. "?v" (string.rep " " (block:x)) ">")]]
    (for [i 1 (block:y)]
        (table.insert
          code
          (..
            " "
            (if (= i (. block :in-pos 1))
              ">"
              " ")
            (. block :code i)
            (if (= i block.out-pos)
              "^"
              " "))))
    (fish.block code :left [1] :right 1)))

(fn fish.if [then else]
  (let [then (-> then fish.left> fish.>right)
        else (-> else fish.left> fish.>right)
        code [(.. "?vv" (string.rep " " (math.max (else:x) (then:x))) ">")]]
    (for [i 1 (else:y)]
        (table.insert
          code
          (..
            "  "
            (if (= i (. else :in-pos 1))
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
            (if (= i (. then :in-pos 1))
              "> "
              "  ")
            (. then :code i)
            (string.rep " " (- (else:x) (then:x)))
            (if (= i then.out-pos)
              "^"
              " "))))
    (fish.block code :left [1] :right 1)))

(fn fish.while [block]
  (let [block (-> block fish.left> fish.>right)
        code [(.. "v" (string.rep " " (block:x)) "  >")
              (.. "v" (string.rep " " (block:x)) " < ")]]
    (for [i 1 (block:y)]
        (table.insert
          code
          (..
            (if (= i (. block :in-pos 1))
              ">"
              " ")
            (. block :code i)
            (if (= i block.out-pos)
              "?^^"
              "   "))))
    (fish.block code :left [1] :right 1)))

(fn fish.until [block]
  (let [block (-> block fish.left> fish.>right)
        code [(.. "v" (string.rep " " (block:x)) " > ")
              (.. "v" (string.rep " " (block:x)) "  <")]]
    (for [i 1 (block:y)]
        (table.insert
          code
          (..
            (if (= i (. block :in-pos 1))
              ">"
              " ")
            (. block :code i)
            (if (= i block.out-pos)
              "?^^"
              "   "))))
    (fish.block code :left [1] :right 1)))

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
    (< 9 i 16)   (fish.line (string.char (+ i 87)))
    (= 39 i)     (fish.line "\"'\"")
    (< 31 i 127) (fish.line (.. "'" (string.char i) "'"))
    (let [n (tostring (math.abs i))]
      (fish.line
        (..
          (if (< i 0) "0" "")
          (n:reverse)
          (string.rep "a*+" (- (length n) 1))
          (if (< i 0) "-" ""))))))

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
   "n" (fish.line "n")
   "nip" (fish.line "$~")
   "2dup" (fish.line "$:@$:@")
   "over" (fish.line "$:@")})

fish

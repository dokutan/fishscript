# fishscript
An experimental programming language that compiles to [><>](https://esolangs.org/wiki/Fish).

## Usage
0. Install [Lua](https://lua.org/), luajit doesn't work due to a dependency on the `utf8` module
1. Download `fishscript` from the release page, or build it with `make` (requires Fennel)
```sh
./fishscript example.🐟
```

<details open>
<summary>Example</summary>

```factor
# FizzBuzz in fishscript
0
{
    1 +
    1 swap

    dup 3 % 0 = {
        "Fizz"
        swap drop 0 swap
    } when

    dup 5 % 0 = {
        "Buzz"
        swap drop 0 swap
    } when

    swap {
        dup n
    } when

    "\n"

    dup 100 <
} while
end
```
compiles to
```
0v                                                               >;
 v                                                              <
 >1+1$:3%0=?v              >:5%0=?v              >$?v  >ao:'d'(?^^
            >'zziF'oooo$~0$^      >'zzuB'oooo$~0$^  >:n^
```
</details>

## Language documentation

<details open>
<summary>Language documentation</summary>

fishscript | ><> | description
---|---|---
`"string"` | | print string
`123` | | push a number
`{ ... }` | | create a block, useful in combination with `while`, `when`
`# comment` | |
`while` | |
`when` | | if without else
`+` | `+` |
`-` | `-` |
`*` | `*` |
`/` | `,` | division
`%` | `%` |
`=` | `=` |
`>` | `(` |
`<` | `)` |
`dup` | `:` | ( x -- x x )
`drop` | `~` | ( x -- )
`rot` | `@` | ( x y z -- z x y )
`swap` | `$` | ( x y -- y x )
`left` | `{` | shift stack left
`right` | `}` | shift stack right
`reverse` | `r` | reverse stack
`length` | `l` | push length of stack
`end` | `;` | end program
`&` | `&` |
`[` | `[` |
`]` | `]` |
`i` | `i` |
`o` | `o` |
`n` | `n` |
`nip` | `$~` | ( x y -- y )
`2dup` | `$:@$:@` | ( x y -- x y x y )
`over` | `$:@` | ( x y -- x y x )
</details>

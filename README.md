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
```
compiles to
```
0v                                                              <>;
 >1+1$:3%0=?v              >:5%0=?v              >$?v  >ao:'d'(?^^
            >'zziF'oooo$~0$^      >'zzuB'oooo$~0$^  >:n^
```
</details>

## Language documentation

<details open>
<summary>Builtin words</summary>

fishscript | ><> | description
---|---|---
`"string"` | | print string
`'string'` | | push string
`123` | | push an integer
`{ ... }` | | create a block, useful in combination with `while`, `when`
`# comment` | |
`... :foo` | | define `foo`
`INCLUDE: foo` | | include ./foo.🐟
`while` | |
`until` | |
`while*` | | `{ condition } { code } while*`
`if` | | `{ then } { else } if`
`when` | | if without else
`unless` | | if without then
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

</details>

<details open>
<summary>stdlib</summary>
To use these words, include the stdlib with `INCLUDE: stdlib`.

fishscript | ><> | description
---|---|---
`nip` | `$~` | ( x y -- y )
`2dup` | `$:@$:@` | ( x y -- x y x y )
`over` | `$:@` | ( x y -- x y x )
`swapd` | `@@$` | ( x y z -- y x z )
`div`, `÷` | | integer division ( x y -- x/y )
`not` | `0=` |
`!=` | `=0=` |
`>=` | `(0=` |
`<=` | `)0=` |
`nth` | | push the nth element from the top of the stack (`1 nth` = `dup`)
`abs` | `:0(2*1$-*n` |
`floor` | `:1%-` |

</details>

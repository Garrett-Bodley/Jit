# Jit

This is a in-progress implementation of a Git client built in Ruby. It follows James Coglan's [Building Git in Ruby](https://shop.jcoglan.com/building-git/), an extremely well written book which I highly recommend.

The implementation starts with a bare-bones program that only works in a flat directory (read: does not understand nested directories) and cannot recognize executable files. Features are added bit by bit as you reverse engineer Git internals from the ground up.

Part of the fun (and challenge) of this project is that `jit` is self hosted, meaning `jit` is used to track itself throughout its own development.

My implementation does not (currently) have networking functionality, so I've pushed this repo to GitHub via some [trickery](#trickery)

# Contents

- [Getting Started](#getting-started)
  - [Supported Commands](#supported-commands)
- [Jit Overview](#jit-overview)
- [Database](#database)
  - [Database Overview](#database-overview)
  - [Blob](#blob)
  - [Tree](#tree)
  - [Commit](#commit)
- [Index](#index)
  - [Index Overview](#index-overview)
  - [Index Structure](#index-structure)
  - [Index Entry](#index-entry)
- [Trickery](#trickery)


# Getting Started

Jit is built for Unix-based systems and does not support Windows. 

Jit should work out of the box after cloning the repository but will require you to enter the path to the binary file when called.

ex: 
```
./relative/path/to/Jit/bin/jit init
```

If you want to call Jit directly without specifying the path you can modify your `PATH` env

```
# ~/.profile

export JIT_PATH="/Absolute/path/to/Jit"
export PATH="$JIT_PATH/bin:$PATH"
```

## Supported Commands:

```
jit init
jit add <filename|dirname|.>
jit commit
jit status
```

`jit commit` does not currently support passing a message via flags (e.g. `jit commit -m "Commit message."`) but rather reads from `stdin` and writes whatever it finds as the commit message. Commit messages can be piped in via the `echo` command or by calling `cat` on a file that contains your message.

ex:
```
echo "Example commit message." | jit commit

# or

cat ~/Somewhere/COMMIT_MSG.txt | jit commit
```

# Jit Overview

- A commit is a snapshot of your workspace, not a diff.
- Your commit history exists as a Directed Acyclic Graph (DAG) where each commit points towards its parent.
- Jit makes extensive use of hashing to prevent duplicate records from being stored.

[Main Contents](#contents)

## Database

- [Database Overview](#database-overview)
- [Blob](#blob)
- [Tree](#tree)
- [Commit](#commit)
- [Main Contents](#contents)

### Database Overview
- Located in `.git/objects`
- Jit's database utilizes content-addressable storage. Each entry is hashed via `SHA-1` and stored in `.git/objects/sh/RemainingThirtyEightSHA1CharactersHere` where `sh` are the first two bytes of the hash and `RemainingThirtyEightSHA1CharactersHere` are the remaining 38 characters of that same `SHA-1`.
- Jit uses Zlib's `deflate` and `inflate` algorithm to compress data, allowing the database to archive numerous snapshots while utilizing minimal storage.
-  There are three types of objects stored in the database: [Blob](#blob), [Tree](#tree), and [Commit](#commit).

  [Database Contents](#database)

### Blob
  - A **Blob** is a snapshot of a file's content at a particular point in time. The content is prepended with the word `blob`, a space, the size of the content in bytes, and a null byte.
  - When a blob is stored in the database its content is hashed via `SHA-1`. That hash is used as its `oid`. Then the metadata is prepended before Zlib compression and writing to disk.
  - ex: 
    ```
      > cat .git/objects/3b/18e512dba79e4c8300dd08aeb37f8e728b8dad

      xK��OR04b�H���W(�/�I�D�%

      > cat .git/objects/3b/18e512dba79e4c8300dd08aeb37f8e728b8dad | zlib-flate -uncompress

      blob 12hello world

      > cat .git/objects/3b/18e512dba79e4c8300dd08aeb37f8e728b8dad | zlib-flate -uncompress | hexdump -C

      00000000  62 6c 6f 62 20 31 32 00  68 65 6c 6c 6f 20 77 6f  |blob 12.hello wo|
      00000010  72 6c 64 0a                                       |rld.|
      00000014
    ```

  [Database Contents](#database)

  ### Tree
  - A **Tree** is Jit's representation of a directory. Similar to blobs, a tree's content is prepended by the word `tree`, a space, the size of the content in bytes, and a null byte.
  - A tree's content consists of a binary packed list of the objects located inside of that directory.
  - Each object lists its file mode and name followed by a binary representation of that object's `SHA-1` hash.
  - Interestingly, the mode recorded in Jit's database are not accurate representation of the file system.
    - Directories have their mode stored as `40000`, ignoring their read/write/execute permissions
    - Non-exectuable files are given the mode `100644`, regardless of the permissions of group or world (For example, a file on disk with the permissions of `100677` will be listed in git as `100644`).
    - Executable files are given the mode `100755`, regardless of the system's other permissions.
  - The `SHA` of a directory corresponds to another Tree in the objects database. This means we are required to build the Trees bottom-up via a DFS traversal of the file system.
  - This method of storing a tree of information where each tree is labelled with the hash of its
children is called a [**Merkle tree**](https://en.wikipedia.org/wiki/Merkle_tree)
  - ex: 
    ```
      > tree
      .
      ├── bar.txt
      ├── executable_file
      ├── foo.txt
      └── subdirectory
          ├── ipsum.txt
          └── lorem.txt

      # ex tree oid: ab0034597a3f1803ef6aa1be6910c9390bdf04a0

      > cat .git/objects/ab/0034597a3f1803ef6aa1be6910c9390bdf04a0 

      x+)JMU045b040031QHJ,�+�(;�~�gm�VO�}���S�mTbnj��Z��\Z����������l�ٛ.^s���\Wu�Г���P��������M�ٸ �C�  {�)va���41��Ҥ�̢����J���;��+o�Zwb��e���zTsM|F%  

      > cat .git/objects/ab/0034597a3f1803ef6aa1be6910c9390bdf04a0 | zlib-flate -uncompress

      tree 152100644 bar.txtW�Y���}k�I ����$-��100755 executable_file�⛲��CK�)�wZ���S�100644 foo.txt%|�d,��T���?-�>V�>��40000 subdirectoryo븕�#��~Ȳ�����Z�|�%

      > cat .git/objects/ab/0034597a3f1803ef6aa1be6910c9390bdf04a0 | zlib-flate -uncompress | hexdump -C

      00000000  74 72 65 65 20 31 35 32  00 31 30 30 36 34 34 20  |tree 152.100644 |
      00000010  62 61 72 2e 74 78 74 00  57 16 ca 59 87 cb f9 7d  |bar.txt.W..Y...}|
      00000020  6b b5 49 20 be a6 ad de  24 2d 87 e6 31 30 30 37  |k.I ....$-..1007|
      00000030  35 35 20 65 78 65 63 75  74 61 62 6c 65 5f 66 69  |55 executable_fi|
      00000040  6c 65 00 e6 9d e2 9b b2  d1 d6 43 4b 8b 29 ae 77  |le........CK.).w|
      00000050  5a d8 c2 e4 8c 53 91 31  30 30 36 34 34 20 66 6f  |Z....S.100644 fo|
      00000060  6f 2e 74 78 74 00 25 7c  c5 64 2c b1 a0 54 f0 8c  |o.txt.%|.d,..T..|
      00000070  c8 3f 2d 94 3e 56 fd 3e  be 99 34 30 30 30 30 20  |.?-.>V.>..40000 |
      00000080  73 75 62 64 69 72 65 63  74 6f 72 79 00 6f eb b8  |subdirectory.o..|
      00000090  95 8f 23 b1 f5 7e c8 b2  a3 a6 af f9 ad 5a e2 7c  |..#..~.......Z.||
      000000a0  dd                                                |.|
      000000a1
    ```

[Database Contents](#database)

  ### Commit
  - A **Commit** lists the top-level tree of the snapshot, the parent commit, the author, the committer, an empty line, and the commit message.
  - Similar to Blobs and Trees, a Commit's content is prepended by the word `commit`, a space, the length of the content in bytes, and a null byte.
  - If a commit does not have a parent it is the root commit.
  - ex: 
    ```

      # ex commit oid: cf95d0d189c17ffea37edc8e89d17a6c758356f7

      > cat .git/objects/cf/95d0d189c17ffea37edc8e89d17a6c758356f7 

        x��A
        �0E]�sK�4"��
                    x�I2i
                        M[b���A�������
        qTk%

      > cat .git/objects/cf/95d0d189c17ffea37edc8e89d17a6c758356f7 | zlib-flate -uncompress

      commit 257tree aaa96ced2d9a1c8e72c56b253a0e2fe78393feb7
      parent 9b73f9f0adc536eeb57246741a734f6dadfc33fd
      author Garrett Bodley <garrett.bodley@gmail.com> 1706661297 -0500
      committer Garrett Bodley <garrett.bodley@gmail.com> 1706661297 -0500

      This is an example commit

      > cat .git/objects/cf/95d0d189c17ffea37edc8e89d17a6c758356f7 | zlib-flate -uncompress | hexdump -C

      00000000  63 6f 6d 6d 69 74 20 32  35 37 00 74 72 65 65 20  |commit 257.tree |
      00000010  61 61 61 39 36 63 65 64  32 64 39 61 31 63 38 65  |aaa96ced2d9a1c8e|
      00000020  37 32 63 35 36 62 32 35  33 61 30 65 32 66 65 37  |72c56b253a0e2fe7|
      00000030  38 33 39 33 66 65 62 37  0a 70 61 72 65 6e 74 20  |8393feb7.parent |
      00000040  39 62 37 33 66 39 66 30  61 64 63 35 33 36 65 65  |9b73f9f0adc536ee|
      00000050  62 35 37 32 34 36 37 34  31 61 37 33 34 66 36 64  |b57246741a734f6d|
      00000060  61 64 66 63 33 33 66 64  0a 61 75 74 68 6f 72 20  |adfc33fd.author |
      00000070  47 61 72 72 65 74 74 20  42 6f 64 6c 65 79 20 3c  |Garrett Bodley <|
      00000080  67 61 72 72 65 74 74 2e  62 6f 64 6c 65 79 40 67  |garrett.bodley@g|
      00000090  6d 61 69 6c 2e 63 6f 6d  3e 20 31 37 30 36 36 36  |mail.com> 170666|
      000000a0  31 32 39 37 20 2d 30 35  30 30 0a 63 6f 6d 6d 69  |1297 -0500.commi|
      000000b0  74 74 65 72 20 47 61 72  72 65 74 74 20 42 6f 64  |tter Garrett Bod|
      000000c0  6c 65 79 20 3c 67 61 72  72 65 74 74 2e 62 6f 64  |ley <garrett.bod|
      000000d0  6c 65 79 40 67 6d 61 69  6c 2e 63 6f 6d 3e 20 31  |ley@gmail.com> 1|
      000000e0  37 30 36 36 36 31 32 39  37 20 2d 30 35 30 30 0a  |706661297 -0500.|
      000000f0  0a 54 68 69 73 20 69 73  20 61 6e 20 65 78 61 6d  |.This is an exam|
      00000100  70 6c 65 20 63 6f 6d 6d  69 74 2e 0a              |ple commit..|
      0000010c
    ```

[Database Contents](#database)

## Index

- [Index Overview](#index-overview)
- [Index Structure](#index-structure)
- [Index Entry](#index-entry)
- [Main Contents](#contents)
### Index Overview

- Located at `.git/index`
- The index functions as a cache that optimizes the performance of Jit and enables new functionality
  - It allows us to add files incrementally instead of committing the entire workspace at the time of each snapshot.
  - It is used for the `status` and `diff` commands. The cache of `oid`s prevents the need to read and hash every file in the workspace when comparing the workspace files with the objects stored in the database. 
  - It stores important metadata about each file, allowing us to quickly detect which files in the workspace have changed since we last called `jit add`.
- Utilizes a custom binary packing format

[Index Contents](#index)

### Index Structure

- Begins with a 12 byte header
  - A four byte signature: `DIRC` (stands for 'dircache')
  - A 4 byte version number (2, 3, and 4 are supported)
  - 32-bit count of entries currently listed in the index
- This header is immediately followed by a list of [Entries](#index-entry)
- The index is terminated with a 20 byte `SHA-1` of its contents which functions as a checksum to verify data integrity when reading.

```
  # Example repo with all files tracked/committed:

  > tree

  .
  ├── hello.txt
  └── world.txt

  # Hexdump the first 12 bytes of .git/index

  > head -c 12 .git/index | hexdump -C

  00000000  44 49 52 43 00 00 00 02  00 00 00 02              |DIRC........|

  # Index header has the chars DIRC, a 4 byte version number (v2), and the number of files in the index (2 tracked files).
```

[Index Contents](#index)

### Index Entry
Each entry consists of:
- 10, 4-byte numbers
  - ctime seconds
  - ctime nanosecond fractions
  - mtime seconds
  - mtime nanosecond fractions
  - dev
  - ino
  - mode
  - uid
  - gid
  - file size
- The 20 byte `SHA-1` hash of the object
- A two-byte set of flag bits
  - The high 4 bits specify a number of different modes. I haven't implemented those modes yet and thus do not know what they do.
  - The low 12 bits specify the length of the filename in bytes.
    - File paths are allowed to be longer than 4095 chars (though I don't know why you'd do that to yourself).
    - If Jit sees the path length is set to 4095, it defaults to incremental scanning until it finds a null byte.
- The filename terminated by a null byte
- Each entry is then padded with null bytes until the total length of the entry in bytes is a multiple of 8.
  - This padding helps speed up reading of the index, allowing the parser to read in 8 byte chunks instead of byte by byte.


```
  # Example repo with all files tracked/committed

  > tree

  .
  ├── hello.txt
  └── world.txt

  # If you want to follow along on your own machine:

  jit init index-test && cd index-test
  echo 'hello' > hello.txt & echo 'world' > world.txt
  jit add . && echo "First commit." | jit commit

  # Commands are specified using jit but you can use git and it should work the same.
  # Because Git hashes are based on content the index and hash values should be identical.
  #   (Though the stat values, and therefore checksum value will differ)

  # --------------------------------------------------------------------------------

  # Hexdump from the start of the first entry in .git/index to the end of the file

  > tail -c +13 .git/index | hexdump -C

  00000000  65 ba b6 45 1e a9 38 d2  65 ba b6 45 1e a9 38 d2  |e..E..8.e..E..8.|
  00000010  01 00 00 0e 04 c2 ef 70  00 00 81 a4 00 00 01 f5  |.......p........|
  00000020  00 00 00 14 00 00 00 06  ce 01 36 25 03 0b a8 db  |..........6%....|
  00000030  a9 06 f7 56 96 7f 9e 9c  a3 94 46 4a 00 09 68 65  |...V......FJ..he|
  00000040  6c 6c 6f 2e 74 78 74 00  65 ba b6 4a 00 e4 1b 49  |llo.txt.e..J...I|
  00000050  65 ba b6 4a 00 e4 1b 49  01 00 00 0e 04 c2 ef 75  |e..J...I.......u|
  00000060  00 00 81 a4 00 00 01 f5  00 00 00 14 00 00 00 06  |................|
  00000070  cc 62 8c cd 10 74 2b ae  a8 24 1c 59 24 df 99 2b  |.b...t+..$.Y$..+|
  00000080  5c 01 9f 71 00 09 77 6f  72 6c 64 2e 74 78 74 00  |\..q..world.txt.|
  00000090  79 12 0a d2 2d 63 7c 8c  15 10 72 15 24 ab 35 87  |y...-c|...r.$.5.|
  000000a0  1b 19 07 61                                       |...a|
  000000a4

  # Hexdump the 10, 4-byte numbers of the first entry

  > tail -c +13 .git/index | head -c 40 | hexdump -C

  00000000  65 ba b6 45 1e a9 38 d2  65 ba b6 45 1e a9 38 d2  |e..E..8.e..E..8.|
  00000010  01 00 00 0e 04 c2 ef 70  00 00 81 a4 00 00 01 f5  |.......p........|
  00000020  00 00 00 14 00 00 00 06                           |........|
  00000028

  # Followed by the 20 byte oid of the hashed object

  > tail -c +53 .git/index | head -c 20 | hexdump -C

  00000000  ce 01 36 25 03 0b a8 db  a9 06 f7 56 96 7f 9e 9c  |..6%.......V....|
  00000010  a3 94 46 4a 

  # If we look in the objects database we can see there's an object with that id!
  # In this case it's a blob
  
  > cat .git/objects/ce/013625030ba8dba906f756967f9e9ca394464a | zlib-flate -uncompress

  blob 6hello

  # The next two bytes contain flags (currently not implemented) and the length of the filename

  > tail -c +73 .git/index | head -c 2 | hexdump -C

  00000000  00 09                                             |..|

  # Those flag bytes indicate the filename is 9 bytes long. Let's read the next 9 bytes, plus one for the null terminated byte.

  > tail -c +75 .git/index | head -c 10 | hexdump -C

  00000000  68 65 6c 6c 6f 2e 74 78  74 00                    |hello.txt.|

  # We have read 40 + 20 + 2 + 10 bytes, or 72 bytes in total.
  # 72 is a multiple of 8, so the next byte should be at the start of the next entry.
  # After calling hexdump, we find that to be the case.

  > tail -c +85 .git/index | hexdump -C

  00000000  65 ba b6 4a 00 e4 1b 49  65 ba b6 4a 00 e4 1b 49  |e..J...Ie..J...I|
  00000010  01 00 00 0e 04 c2 ef 75  00 00 81 a4 00 00 01 f5  |.......u........|
  00000020  00 00 00 14 00 00 00 06  cc 62 8c cd 10 74 2b ae  |.........b...t+.|
  00000030  a8 24 1c 59 24 df 99 2b  5c 01 9f 71 00 09 77 6f  |.$.Y$..+\..q..wo|
  00000040  72 6c 64 2e 74 78 74 00  79 12 0a d2 2d 63 7c 8c  |rld.txt.y...-c|.|
  00000050  15 10 72 15 24 ab 35 87  1b 19 07 61              |..r.$.5....a|
  0000005c

  # The final 20 bytes should have a checksum hash for the prior content.
  # We can use that to verify the index's data integrity

  > tail -c 20 .git/index | hexdump -C

  00000000  79 12 0a d2 2d 63 7c 8c  15 10 72 15 24 ab 35 87  |y...-c|...r.$.5.|
  00000010  1b 19 07 61

  If we compute the `SHA-1` of everything but the last 20 bytes of the index we see that it matches so we know our data is valid.

  > head -c $(($(wc -c < .git/index) - 20)) .git/index | sha1sum

  79120ad22d637c8c1510721524ab35871b190761  -
```

[Index Contents](#index)

## Trickery

My implementation does not currently have networking functionality. In order to track this repository I have set up an archive mirror that updates via a bash script.

I chose this strategy as a means to avoid `git` mutating the `.git` folder in my working directory. As my implementation is incomplete, any mutations might render my `.git` folder unreadable to `jit` and break the project. To avoid this I created a mirrored repo that copies all files and changes from my main working directory but ignores the `.git` folder after initialization. That mirrored repo is connected to the remote hosted on GitHub, allowing me to push without worrying about mutating the `.git` folder in my working directory.

This strategy is somewhat fragile, as there is nothing to ensure that the changes copied over correspond to the most recent commit in my working directory. The intended use is to call `jit-archive` immediately after I make a commit in my working directory.


```
#! /usr/bin/env bash

JIT_PATH=$(realpath ~/Code/git-in-ruby/my-jit)
ARCHIVE_PATH=$(realpath ~/Code/git-in-ruby/jit-archive)

# Copy files from my-jit to jit-archive
rsync -av --exclude='.[^.]*' --delete "$JIT_PATH/" "$ARCHIVE_PATH"

# Grab most recent commit message from my-jit
COMMIT_MSG=$(git -C "$JIT_PATH" log -1 --pretty=format:'%B')

# Make a new commit in jit-archive using that message
git -C "$ARCHIVE_PATH" add .
git -C "$ARCHIVE_PATH" commit -m "$COMMIT_MSG"
git -C "$ARCHIVE_PATH" push

```

[Main Contents](#contents)
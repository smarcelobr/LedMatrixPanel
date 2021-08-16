--file.rename('ok.flag','not_ok.flag')
file.rename('not_ok.flag','ok.flag')
print(node.LFS.reload("lfs.img"))

class FtpFile {
 final String name;
 final int size;
 final DateTime? modifyTime;
 final String path;
 final bool isDirectory;

 FtpFile({
   required this.name,
   required this.size,
   this.modifyTime,
   required this.path,
   this.isDirectory = false, // default dosya
 });

 String get sizeFormatted {
   if (size < 1024) return '$size B';
   if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
   return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
 }
}
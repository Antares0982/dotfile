<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:str="http://exslt.org/strings" exclude-result-prefixes="str">
  <xsl:output method="html" encoding="UTF-8" doctype-system="about:legacy-compat"/>
  <xsl:template match="/list">
    <html lang="zh-CN">
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>L4D2 地图文件</title>
        <style>
          body { max-width: 960px; margin: auto; padding: 24px; font: 16px system-ui; background: #f5f5f5; color: #222; }
          ul { list-style: none; padding: 0; display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 16px; }
          li { padding: 16px; background: white; border-radius: 8px; overflow-wrap: anywhere; }
          img { display: block; max-width: 100%; height: 180px; object-fit: contain; margin: 12px auto; }
          a { color: #174ea6; } small { display: block; margin: 8px 0; }
          form { padding: 16px; background: white; border-radius: 8px; }
          input, button { margin: 8px 0; max-width: 100%; font: inherit; }
          progress { display: block; width: 100%; }
        </style>
      </head>
      <body>
        <h1>L4D2 地图文件</h1>
        <p>下载 VPK 后放入游戏的 left4dead2/addons 目录。</p>
        <form id="upload">
          <label for="file">上传 VPK 或图片</label><br/>
          <input id="file" type="file" accept=".vpk,.jpg,.jpeg,.png,.gif,.webp" required="required"/><br/>
          <small>支持 VPK、JPG/JPEG、PNG、GIF、WebP，仅按扩展名检查。单文件最大 2 GiB，同名文件会被覆盖。</small>
          <button id="submit" type="submit">上传文件</button>
          <progress id="progress" max="100" value="0" aria-label="上传进度"></progress>
          <p id="status" role="status" aria-live="polite"></p>
        </form>
        <script><![CDATA[
          const form = document.getElementById('upload');
          const input = document.getElementById('file');
          const button = document.getElementById('submit');
          const progress = document.getElementById('progress');
          const status = document.getElementById('status');
          form.addEventListener('submit', event => {
            event.preventDefault();
            const file = input.files[0];
            if (!file) return;
            if (file.name.startsWith('.') || !/\.(vpk|jpe?g|png|gif|webp)$/i.test(file.name)) {
              status.textContent = '请选择 VPK、JPG/JPEG、PNG、GIF 或 WebP 文件，文件名不能以点开头。';
              return;
            }
            if (file.size > 2 * 1024 ** 3) {
              status.textContent = '文件超过 2 GiB 上限。';
              return;
            }
            button.disabled = input.disabled = true;
            progress.value = 0;
            status.textContent = '正在上传…';
            const request = new XMLHttpRequest();
            request.open('PUT', '/' + encodeURIComponent(file.name));
            request.upload.addEventListener('progress', event => {
              if (event.lengthComputable) progress.value = event.loaded / event.total * 100;
            });
            request.addEventListener('load', () => {
              if (request.status >= 200 && request.status < 300) {
                status.textContent = '上传成功，正在刷新列表…';
                location.reload();
              } else {
                const errors = {
                  401: '认证失败，请刷新页面后重新登录。',
                  403: '无法写入此文件。',
                  413: '文件超过 2 GiB 上限。'
                };
                status.textContent = errors[request.status] || '上传失败（HTTP ' + request.status + '），请重试。';
              }
            });
            request.addEventListener('error', () => {
              status.textContent = '网络错误，上传未确认完成，请刷新列表检查后重试。';
            });
            request.addEventListener('loadend', () => {
              button.disabled = input.disabled = false;
            });
            request.send(file);
          });
        ]]></script>
        <ul>
          <xsl:for-each select="file[not(starts-with(., '.'))]">
            <xsl:sort select="."/>
            <xsl:variable name="name" select="translate(., 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')"/>
            <xsl:variable name="extension" select="substring($name, string-length($name) - 3)"/>
            <xsl:variable name="image" select="$extension = '.jpg' or $extension = '.png' or $extension = '.gif' or substring($name, string-length($name) - 4) = '.jpeg' or substring($name, string-length($name) - 4) = '.webp'"/>
            <xsl:if test="$extension = '.vpk' or $image">
              <xsl:variable name="url" select="concat('/', str:encode-uri(string(.), true()))"/>
              <li>
                <strong><xsl:value-of select="."/></strong>
                <small><xsl:value-of select="format-number(@size div 1048576, '0.##')"/> MiB</small>
                <xsl:if test="$image">
                  <a href="{$url}"><img src="{$url}" alt="{.}" loading="lazy"/></a>
                </xsl:if>
                <a href="{$url}" download="{.}">下载</a>
              </li>
            </xsl:if>
          </xsl:for-each>
        </ul>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>

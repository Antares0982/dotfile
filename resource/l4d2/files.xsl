<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:str="http://exslt.org/strings" exclude-result-prefixes="str">
  <xsl:output method="html" encoding="UTF-8" doctype-system="about:legacy-compat"/>
  <xsl:template match="/list">
    <html lang="zh-CN">
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>L4D2 地图下载</title>
        <style>
          body { max-width: 960px; margin: auto; padding: 24px; font: 16px system-ui; background: #f5f5f5; color: #222; }
          ul { list-style: none; padding: 0; display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 16px; }
          li { padding: 16px; background: white; border-radius: 8px; overflow-wrap: anywhere; }
          img { display: block; max-width: 100%; height: 180px; object-fit: contain; margin: 12px auto; }
          a { color: #174ea6; } small { display: block; margin: 8px 0; }
        </style>
      </head>
      <body>
        <h1>L4D2 地图下载</h1>
        <p>下载 VPK 后放入游戏的 left4dead2/addons 目录。</p>
        <ul>
          <xsl:for-each select="file[not(starts-with(., '.'))]">
            <xsl:sort select="."/>
            <xsl:variable name="extension" select="translate(substring(., string-length(.) - 3), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')"/>
            <xsl:if test="$extension = '.vpk' or $extension = '.jpg'">
              <xsl:variable name="url" select="concat('/', str:encode-uri(string(.), true()))"/>
              <li>
                <strong><xsl:value-of select="."/></strong>
                <small><xsl:value-of select="format-number(@size div 1048576, '0.##')"/> MiB</small>
                <xsl:if test="$extension = '.jpg'">
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

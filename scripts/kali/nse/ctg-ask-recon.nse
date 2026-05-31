-- CTG ask-recon — lightweight lab asset fingerprint (defensive inventory).
-- Hacker Planet LLC · authorized lab use only.
--
-- Usage (via ctg-nmap-ask.sh Phase 5):
--   nmap --script=ctg-ask-recon --script-dir=/opt/ctg/nmap-ask/nse <target>
--
description = [[
CTG defensive recon helper: reports open HTTP/HTTPS titles and SSH banners
for authorized lab asset inventory. No exploit actions.
]]
author = "Hacker Planet LLC"
license = "Same as Nmap"
categories = {"safe", "discovery"}

portrule = function(host, port)
  return port.protocol == "tcp" and port.number == 80
      or port.number == 443
      or port.number == 22
end

action = function(host, port)
  local output = {}
  if port.number == 22 then
    local banner = stdnse.get_banner(host, port)
    if banner then
      table.insert(output, "ssh-banner: " .. string.gsub(banner, "\n", " "))
    end
  elseif port.number == 80 or port.number == 443 then
    local scheme = port.number == 443 and "https" or "http"
    local resp = http.get(host, port, "/", {ssl=(port.number==443)})
    if resp and resp.status then
      table.insert(output, scheme .. "-status: " .. tostring(resp.status))
      if resp.header and resp.header["server"] then
        table.insert(output, "server: " .. resp.header["server"])
      end
    end
  end
  if #output == 0 then
    return nil
  end
  return table.concat(output, " | ")
end

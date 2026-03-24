param(
  [Parameter(Mandatory = $true)]
  [string]$AppToken,
  [Parameter(Mandatory = $true)]
  [string]$AppId,
  [Parameter(Mandatory = $true)]
  [string]$WabaId,
  [string]$ApiVersion = "v23.0"
)

$ErrorActionPreference = "Stop"

function Invoke-GraphPostJson {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Uri,
    [Parameter(Mandatory = $true)]
    [hashtable]$Body
  )

  return Invoke-RestMethod -Method Post -Uri $Uri -Headers @{
    Authorization = "Bearer $AppToken"
    "Content-Type" = "application/json"
  } -Body ($Body | ConvertTo-Json -Depth 20)
}

Write-Host "Preparing template assets..."
$publicDir = Join-Path $PSScriptRoot "public"
New-Item -ItemType Directory -Path $publicDir -Force | Out-Null

$assets = @(
  @{ Name = "groceries"; File = "groceries.jpg"; Url = "https://scontent.xx.fbcdn.net/mci_ab/uap/asset_manager/id/?ab_b=e&ab_page=AssetManagerID&ab_entry=1530053877871776" },
  @{ Name = "salad_bowl"; File = "salad_bowl.jpg"; Url = "https://scontent.xx.fbcdn.net/mci_ab/uap/asset_manager/id/?ab_b=e&ab_page=AssetManagerID&ab_entry=3255815791260974" },
  @{ Name = "sheet_pan_dinner"; File = "sheet_pan_dinner.jpg"; Url = "https://scontent.xx.fbcdn.net/mci_ab/uap/asset_manager/id/?ab_b=e&ab_page=AssetManagerID&ab_entry=1389202275965231" },
  @{ Name = "strawberries"; File = "strawberries.jpg"; Url = "https://scontent.xx.fbcdn.net/mci_ab/uap/asset_manager/id/?ab_b=e&ab_page=AssetManagerID&ab_entry=1393969325614091" }
)

$handles = @{}
foreach ($asset in $assets) {
  $filePath = Join-Path $publicDir $asset.File
  Write-Host "Downloading $($asset.File)..."
  Invoke-WebRequest -Uri $asset.Url -OutFile $filePath | Out-Null

  $fileLength = (Get-Item $filePath).Length
  $uploadStartUri = "https://graph.facebook.com/$ApiVersion/$AppId/uploads?file_name=$($asset.File)&file_length=$fileLength&file_type=image/jpg&access_token=$AppToken"
  $uploadStart = Invoke-RestMethod -Method Post -Uri $uploadStartUri
  $uploadSessionId = $uploadStart.id
  Write-Host "Upload session: $uploadSessionId"

  $bytes = [System.IO.File]::ReadAllBytes($filePath)
  $uploadUri = "https://graph.facebook.com/$ApiVersion/$uploadSessionId"
  $uploadResp = Invoke-RestMethod -Method Post -Uri $uploadUri -Headers @{
    Authorization = "OAuth $AppToken"
    file_offset = "0"
    "Content-Type" = "application/octet-stream"
  } -Body $bytes

  $handles[$asset.Name] = $uploadResp.h
  Write-Host "Handle for $($asset.Name): $($uploadResp.h)"
}

Write-Host "Creating grocery_delivery_utility..."
Invoke-GraphPostJson -Uri "https://graph.facebook.com/$ApiVersion/$WabaId/message_templates" -Body @{
  name = "grocery_delivery_utility"
  language = "en_US"
  category = "marketing"
  components = @(
    @{
      type = "header"
      format = "image"
      example = @{
        header_handle = @($handles["groceries"])
      }
    },
    @{
      type = "body"
      text = "Free delivery for all online orders with Jasper's Market"
    },
    @{
      type = "footer"
      text = "developers.facebook.com"
    },
    @{
      type = "buttons"
      buttons = @(
        @{
          type = "url"
          text = "Get free delivery"
          url = "https://developers.facebook.com/documentation/business-messaging/whatsapp/templates/utility-templates/utility-templates"
        }
      )
    }
  )
} | Out-Null

Write-Host "Creating recipe_media_carousel..."
Invoke-GraphPostJson -Uri "https://graph.facebook.com/$ApiVersion/$WabaId/message_templates" -Body @{
  name = "recipe_media_carousel"
  language = "en_US"
  category = "marketing"
  components = @(
    @{
      type = "body"
      text = "Our in-house chefs have prepared some delicious and fresh summer recipes."
    },
    @{
      type = "carousel"
      cards = @(
        @{
          components = @(
            @{
              type = "header"
              format = "image"
              example = @{
                header_handle = @($handles["sheet_pan_dinner"])
              }
            },
            @{
              type = "body"
              text = "Simple and Healthy Sheet Pan Dinner to Feed the Whole Family"
            },
            @{
              type = "buttons"
              buttons = @(
                @{
                  type = "url"
                  text = "Get this recipe"
                  url = "https://developers.facebook.com/documentation/business-messaging/whatsapp/templates/marketing-templates/media-card-carousel-templates"
                }
              )
            }
          )
        },
        @{
          components = @(
            @{
              type = "header"
              format = "image"
              example = @{
                header_handle = @($handles["salad_bowl"])
              }
            },
            @{
              type = "body"
              text = "3 Plant-Powered Salad Bowls to Fuel Your Week"
            },
            @{
              type = "buttons"
              buttons = @(
                @{
                  type = "url"
                  text = "Get this recipe"
                  url = "https://developers.facebook.com/documentation/business-messaging/whatsapp/templates/marketing-templates/media-card-carousel-templates"
                }
              )
            }
          )
        }
      )
    }
  )
} | Out-Null

Write-Host "Creating strawberries_limited_offer..."
Invoke-GraphPostJson -Uri "https://graph.facebook.com/$ApiVersion/$WabaId/message_templates" -Body @{
  name = "strawberries_limited_offer"
  language = "en_US"
  category = "marketing"
  components = @(
    @{
      type = "header"
      format = "image"
      example = @{
        header_handle = @($handles["strawberries"])
      }
    },
    @{
      type = "limited_time_offer"
      limited_time_offer = @{
        text = "Expiring offer!"
        has_expiration = $true
      }
    },
    @{
      type = "body"
      text = "Fresh strawberries at Jasper's Market are now 20% off! Get them while they last"
    },
    @{
      type = "buttons"
      buttons = @(
        @{
          type = "copy_code"
          example = "BERRIES20"
        },
        @{
          type = "url"
          text = "Shop now"
          url = "https://developers.facebook.com/documentation/business-messaging/whatsapp/templates/marketing-templates/limited-time-offer-templates"
        }
      )
    }
  )
} | Out-Null

Write-Host "Template setup finished. Check WhatsApp Manager for approval status."

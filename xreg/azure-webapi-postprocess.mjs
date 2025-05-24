#!/usr/bin/env node
import { promises as fs } from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// Updated to work with the registry structure from xr download
const REGISTRY_DIR = process.argv[2] || path.join(__dirname, '../live')

async function renameJsonFiles(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true })
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      await renameJsonFiles(fullPath)
    } else {
      let newName
      if (/\$details$/i.test(entry.name)) {
        newName = `${entry.name}.json`
      } else if (entry.name === 'meta') {
        newName = 'meta.json'
      } else if (entry.name === 'model') {
        newName = 'model.json'
      } else if (entry.name === 'export') {
        newName = 'export.json'
      }
      if (newName) {
        await fs.rename(fullPath, path.join(dir, newName))
        console.log(`Renamed ${entry.name} to ${newName}`)
      }
    }
  }
}

async function writeRootConfig() {
  const content = `<?xml version="1.0" encoding="utf-8"?>
<configuration>
    <system.webServer>
        <defaultDocument>
            <files>
                <clear />
                <add value="index.json" />
            </files>
        </defaultDocument>
        <rewrite>
            <rules>
                <rule name="AddJsonExtensionForDetails" stopProcessing="true">
                    <match url="(.*\\$details)" ignoreCase="true" />
                    <action type="Rewrite" url="{R:0}.json" />
                </rule>
                <rule name="AddMetaExtension" stopProcessing="true">
                    <match url="(.*meta)$" ignoreCase="true" />
                    <action type="Rewrite" url="{R:0}.json" />
                </rule>
                 <rule name="AddModelExtension" stopProcessing="true">
                    <match url="(.*model)$" ignoreCase="true" />
                    <action type="Rewrite" url="{R:0}.json" />
                </rule>
                <rule name="AddExportExtension" stopProcessing="true">
                    <match url="(.*export)$" ignoreCase="true" />
                    <action type="Rewrite" url="{R:0}.json" />
                </rule>
            </rules>
        </rewrite>
    </system.webServer>
</configuration>`
  await fs.writeFile(path.join(REGISTRY_DIR, 'web.config'), content, 'utf8')
  console.log('Created root web.config')
}

async function processDirectories(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true })
  for (const entry of entries) {
    if (entry.isDirectory()) {
      const subdir = path.join(dir, entry.name)
      // If this is a 'versions' directory, write the specified web.config
      if (entry.name === 'versions') {
        const config = `<?xml version="1.0" encoding="utf-8"?>
<configuration>
    <system.webServer>
        <httpRedirect enabled="false" />
    </system.webServer>
</configuration>`
        await fs.writeFile(path.join(subdir, 'web.config'), config, 'utf8')
        console.log(`Created web.config for versions directory: ${subdir}`)
      }
      let wroteConfig = false
      // Attempt to locate a $details.json file in the parent directory to obtain schemauri
      const parentDir = dir
      const parentEntries = await fs.readdir(parentDir, { withFileTypes: true })
      const detailsEntry = parentEntries.find(
        (e) => e.isFile() && /\$details\.json$/i.test(e.name),
      )
      if (detailsEntry) {
        const detailsPath = path.join(parentDir, detailsEntry.name)
        try {
          const detailsContent = await fs.readFile(detailsPath, 'utf8')
          const details = JSON.parse(detailsContent)
          if (details.schemauri) {
            const config = `<?xml version="1.0" encoding="utf-8"?>
<configuration>
    <system.webServer>
        <httpRedirect enabled="true"
                      destination="${details.schemauri}"
                      exactDestination="true"
                      childOnly="true"
                      httpResponseStatus="Permanent" />
    </system.webServer>
</configuration>`
            await fs.writeFile(path.join(subdir, 'web.config'), config, 'utf8')
            wroteConfig = true
            console.log(`Created schema redirect web.config for: ${subdir}`)
          }
        } catch (e) {
          // no details file or error parsing
        }
      }

      // If this is a version directory under a "versions" folder and no config has been written,
      // then write a default config file.
      const isVersionDirectory =
        path.basename(dir) === 'versions' && /^\d+\.\d+\.\d+$/.test(entry.name)
      if (!wroteConfig && isVersionDirectory) {
        const defaultConfig = `<?xml version="1.0" encoding="utf-8"?>
<configuration>
    <system.webServer>
        <httpRedirect enabled="true"
                      destination="/"
                      exactDestination="true"
                      childOnly="true"
                      httpResponseStatus="Permanent" />
    </system.webServer>
</configuration>`
        await fs.writeFile(
          path.join(subdir, 'web.config'),
          defaultConfig,
          'utf8',
        )
        console.log(`Created default version redirect web.config for: ${subdir}`)
      }
      await processDirectories(subdir)
    }
  }
}

async function run() {
  console.log(`Processing registry directory: ${REGISTRY_DIR}`)
  
  // Check if directory exists
  try {
    await fs.access(REGISTRY_DIR)
  } catch (error) {
    console.error(`Registry directory not found: ${REGISTRY_DIR}`)
    process.exit(1)
  }
  
  await renameJsonFiles(REGISTRY_DIR)
  await writeRootConfig()
  await processDirectories(REGISTRY_DIR)
  console.log('Postprocessing complete.')
}

run().catch((err) => {
  console.error('Error during postprocessing:', err)
  process.exit(1)
}) 
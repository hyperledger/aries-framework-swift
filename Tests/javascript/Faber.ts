import type { ConnectionStateChangedEvent, CredentialStateChangedEvent, InitConfig } from '@credo-ts/core'
import type { IndyVdrPoolConfig, IndyVdrRegisterCredentialDefinitionOptions } from '@credo-ts/indy-vdr'

import {
  AnonCredsModule,
  LegacyIndyCredentialFormatService,
  LegacyIndyProofFormatService,
  V1CredentialProtocol,
  V1ProofProtocol,
  getUnqualifiedCredentialDefinitionId,
  parseIndyCredentialDefinitionId,
} from '@credo-ts/anoncreds'
import { AskarModule } from '@credo-ts/askar'
import {
  ConnectionsModule,
  ProofsModule,
  AutoAcceptProof,
  AutoAcceptCredential,
  CredentialsModule,
  Agent,
  HttpOutboundTransport,
  KeyType,
  TypedArrayEncoder,
  DidsModule,
  ConnectionEventTypes,
  CredentialEventTypes,
  utils,
} from '@credo-ts/core'
import { IndyVdrRegisterSchemaOptions, IndyVdrAnonCredsRegistry, IndyVdrModule, IndyVdrIndyDidResolver } from '@credo-ts/indy-vdr'
import { agentDependencies, HttpInboundTransport } from '@credo-ts/node'
import { anoncreds } from '@hyperledger/anoncreds-nodejs'
import { ariesAskar } from '@hyperledger/aries-askar-nodejs'
import { indyVdr } from '@hyperledger/indy-vdr-nodejs'

const bcovrin = `{"reqSignature":{},"txn":{"data":{"data":{"alias":"Node1","blskey":"4N8aUNHSgjQVgkpm8nhNEfDf6txHznoYREg9kirmJrkivgL4oSEimFF6nsQ6M41QvhM2Z33nves5vfSn9n1UwNFJBYtWVnHYMATn76vLuL3zU88KyeAYcHfsih3He6UHcXDxcaecHVz6jhCYz1P2UZn2bDVruL5wXpehgBfBaLKm3Ba","blskey_pop":"RahHYiCvoNCtPTrVtP7nMC5eTYrsUA8WjXbdhNc8debh1agE9bGiJxWBXYNFbnJXoXhWFMvyqhqhRoq737YQemH5ik9oL7R4NTTCz2LEZhkgLJzB3QRQqJyBNyv7acbdHrAT8nQ9UkLbaVL9NBpnWXBTw4LEMePaSHEw66RzPNdAX1","client_ip":"138.197.138.255","client_port":9702,"node_ip":"138.197.138.255","node_port":9701,"services":["VALIDATOR"]},"dest":"Gw6pDLhcBcoQesN72qfotTgFa7cbuqZpkX3Xo6pLhPhv"},"metadata":{"from":"Th7MpTaRZVRYnPiabds81Y"},"type":"0"},"txnMetadata":{"seqNo":1,"txnId":"fea82e10e894419fe2bea7d96296a6d46f50f93f9eeda954ec461b2ed2950b62"},"ver":"1"}
{"reqSignature":{},"txn":{"data":{"data":{"alias":"Node2","blskey":"37rAPpXVoxzKhz7d9gkUe52XuXryuLXoM6P6LbWDB7LSbG62Lsb33sfG7zqS8TK1MXwuCHj1FKNzVpsnafmqLG1vXN88rt38mNFs9TENzm4QHdBzsvCuoBnPH7rpYYDo9DZNJePaDvRvqJKByCabubJz3XXKbEeshzpz4Ma5QYpJqjk","blskey_pop":"Qr658mWZ2YC8JXGXwMDQTzuZCWF7NK9EwxphGmcBvCh6ybUuLxbG65nsX4JvD4SPNtkJ2w9ug1yLTj6fgmuDg41TgECXjLCij3RMsV8CwewBVgVN67wsA45DFWvqvLtu4rjNnE9JbdFTc1Z4WCPA3Xan44K1HoHAq9EVeaRYs8zoF5","client_ip":"138.197.138.255","client_port":9704,"node_ip":"138.197.138.255","node_port":9703,"services":["VALIDATOR"]},"dest":"8ECVSk179mjsjKRLWiQtssMLgp6EPhWXtaYyStWPSGAb"},"metadata":{"from":"EbP4aYNeTHL6q385GuVpRV"},"type":"0"},"txnMetadata":{"seqNo":2,"txnId":"1ac8aece2a18ced660fef8694b61aac3af08ba875ce3026a160acbc3a3af35fc"},"ver":"1"}
{"reqSignature":{},"txn":{"data":{"data":{"alias":"Node3","blskey":"3WFpdbg7C5cnLYZwFZevJqhubkFALBfCBBok15GdrKMUhUjGsk3jV6QKj6MZgEubF7oqCafxNdkm7eswgA4sdKTRc82tLGzZBd6vNqU8dupzup6uYUf32KTHTPQbuUM8Yk4QFXjEf2Usu2TJcNkdgpyeUSX42u5LqdDDpNSWUK5deC5","blskey_pop":"QwDeb2CkNSx6r8QC8vGQK3GRv7Yndn84TGNijX8YXHPiagXajyfTjoR87rXUu4G4QLk2cF8NNyqWiYMus1623dELWwx57rLCFqGh7N4ZRbGDRP4fnVcaKg1BcUxQ866Ven4gw8y4N56S5HzxXNBZtLYmhGHvDtk6PFkFwCvxYrNYjh","client_ip":"138.197.138.255","client_port":9706,"node_ip":"138.197.138.255","node_port":9705,"services":["VALIDATOR"]},"dest":"DKVxG2fXXTU8yT5N7hGEbXB3dfdAnYv1JczDUHpmDxya"},"metadata":{"from":"4cU41vWW82ArfxJxHkzXPG"},"type":"0"},"txnMetadata":{"seqNo":3,"txnId":"7e9f355dffa78ed24668f0e0e369fd8c224076571c51e2ea8be5f26479edebe4"},"ver":"1"}
{"reqSignature":{},"txn":{"data":{"data":{"alias":"Node4","blskey":"2zN3bHM1m4rLz54MJHYSwvqzPchYp8jkHswveCLAEJVcX6Mm1wHQD1SkPYMzUDTZvWvhuE6VNAkK3KxVeEmsanSmvjVkReDeBEMxeDaayjcZjFGPydyey1qxBHmTvAnBKoPydvuTAqx5f7YNNRAdeLmUi99gERUU7TD8KfAa6MpQ9bw","blskey_pop":"RPLagxaR5xdimFzwmzYnz4ZhWtYQEj8iR5ZU53T2gitPCyCHQneUn2Huc4oeLd2B2HzkGnjAff4hWTJT6C7qHYB1Mv2wU5iHHGFWkhnTX9WsEAbunJCV2qcaXScKj4tTfvdDKfLiVuU2av6hbsMztirRze7LvYBkRHV3tGwyCptsrP","client_ip":"138.197.138.255","client_port":9708,"node_ip":"138.197.138.255","node_port":9707,"services":["VALIDATOR"]},"dest":"4PS3EDQ3dW1tci1Bp6543CfuuebjFrg36kLAUcskGfaA"},"metadata":{"from":"TWwCRQRZ2ZHMJFn9TzLp7W"},"type":"0"},"txnMetadata":{"seqNo":4,"txnId":"aa5e817d7cc626170eca175822029339a444eb0ee8f0bd20d3b0b76e566fb008"},"ver":"1"}`

const port = 3000

const issueCredentialConfig = {
  goal: 'To issue a credential',
  goalCode: 'issue-vc',
  label: 'Faber College',
  handshake: true,
}

export const indyNetworkConfig = {
  genesisTransactions: bcovrin,
  indyNamespace: 'bcovrin:test',
  isProduction: false,
  connectOnStartup: true,
} satisfies IndyVdrPoolConfig

const config: InitConfig = {
  label: 'faber-oob-credential',
  walletConfig: {
    id: 'faber-oob-credential',
    key: 'testkey0000000000000000000000000',
  },
  endpoints: [`http://localhost:${port}`],
}

const legacyIndyCredentialFormatService = new LegacyIndyCredentialFormatService()
const legacyIndyProofFormatService = new LegacyIndyProofFormatService()
const legacyIndyRegistry = new IndyVdrAnonCredsRegistry()
function getAskarAnonCredsIndyModules() {
  return {
    connections: new ConnectionsModule({
      autoAcceptConnections: true,
    }),
    credentials: new CredentialsModule({
      autoAcceptCredentials: AutoAcceptCredential.ContentApproved,
      credentialProtocols: [
        new V1CredentialProtocol({
          indyCredentialFormat: legacyIndyCredentialFormatService,
        }),
      ],
    }),
    proofs: new ProofsModule({
      autoAcceptProofs: AutoAcceptProof.ContentApproved,
      proofProtocols: [
        new V1ProofProtocol({
          indyProofFormat: legacyIndyProofFormatService,
        }),
      ],
    }),
    anoncreds: new AnonCredsModule({
      registries: [legacyIndyRegistry],
      anoncreds,
    }),
    indyVdr: new IndyVdrModule({
      indyVdr,
      networks: [indyNetworkConfig],
    }),
    askar: new AskarModule({
      ariesAskar,
    }),
    dids: new DidsModule({
      resolvers: [new IndyVdrIndyDidResolver()],
    }),
  } as const
}

const agent = new Agent({
  config,
  dependencies: agentDependencies,
  modules: getAskarAnonCredsIndyModules(),
})
agent.registerOutboundTransport(new HttpOutboundTransport())
agent.registerInboundTransport(new HttpInboundTransport({ port: port }))

var anonCredsIssuerId: string
async function importDid() {
  console.log("Importing DID...")
  const unqualifiedIndyDid = '2jEvRuKmfBJTRa7QowDpNN'
  const did = `did:indy:${indyNetworkConfig.indyNamespace}:${unqualifiedIndyDid}`

  await agent.dids.import({
    did,
    overwrite: true,
    privateKeys: [
      {
        keyType: KeyType.Ed25519,
        privateKey: TypedArrayEncoder.fromString('afjdemoverysercure00000000000000'),
      },
    ],
  })
  anonCredsIssuerId = did
}

function legacyCredDefId(credentialDefinitionId: string) {
  const { namespaceIdentifier, schemaSeqNo, tag } = parseIndyCredentialDefinitionId(credentialDefinitionId)
  const legacyCredentialDefinitionId = getUnqualifiedCredentialDefinitionId(namespaceIdentifier, schemaSeqNo, tag)
  return legacyCredentialDefinitionId
}

async function prepareForIssuance() {
  console.log("Registering schema...")
  const schemaTemplate = {
    name: 'Faber College' + utils.uuid(),
    version: '1.0.0',
    attrNames: ['name', 'degree', 'date'],
    issuerId: anonCredsIssuerId,
  }
  const { schemaState } = await agent.modules.anoncreds.registerSchema<IndyVdrRegisterSchemaOptions>({
    schema: schemaTemplate,
    options: {
      endorserMode: 'internal',
      endorserDid: anonCredsIssuerId,
    },
  })
  if (schemaState.state !== 'finished') {
    throw new Error(
      `Error registering schema: ${schemaState.state === 'failed' ? schemaState.reason : 'Not Finished'}`
    )
  }

  console.log("Registering credential definition...")
  const { credentialDefinitionState } =
  await agent.modules.anoncreds.registerCredentialDefinition<IndyVdrRegisterCredentialDefinitionOptions>({
    credentialDefinition: {
      schemaId: schemaState.schemaId,
      issuerId: anonCredsIssuerId,
      tag: 'latest',
    },
    options: {
      supportRevocation: false,
      endorserMode: 'internal',
      endorserDid: anonCredsIssuerId,
    },
  })

  return { schemaState, credentialDefinitionState }
}

const run = async () => {
  console.log("Agent initializing...")
  await agent.initialize()
  console.log("Agent initialized")
  await importDid()

  const { credentialDefinitionState } = await prepareForIssuance()
  const protocol = new V1CredentialProtocol({
    indyCredentialFormat: legacyIndyCredentialFormatService,
  })
  const { message } = await protocol.createOffer(
    agent.context,
    { 
      credentialFormats: {
        indy: {
          attributes: [
            {
              name: 'name',
              value: 'Alice Smith',
            },
            {
              name: 'degree',
              value: 'Computer Science',
            },
            {
              name: 'date',
              value: '01/01/2022',
            },
          ],
          credentialDefinitionId: legacyCredDefId(credentialDefinitionState.credentialDefinitionId as string),
        },
      },
      autoAcceptCredential: AutoAcceptCredential.ContentApproved,
    },
  )
  const { outOfBandInvitation } = await agent.oob.createInvitation({
      ...issueCredentialConfig,
      messages: [message],
  })

  const urlMessage = outOfBandInvitation.toUrl({ domain: 'http://example.com' })
  console.log(urlMessage)

  agent.events.on<ConnectionStateChangedEvent>(ConnectionEventTypes.ConnectionStateChanged, (e) => {
    console.log("Connection state changed to " + e.payload.connectionRecord.state)
  })
  agent.events.on<CredentialStateChangedEvent>(CredentialEventTypes.CredentialStateChanged, (e) => {
    console.log("Credential state changed to " + e.payload.credentialRecord.state)
  })
}

run()

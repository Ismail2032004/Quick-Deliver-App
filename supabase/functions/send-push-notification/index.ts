import { createClient } from 'npm:@supabase/supabase-js@2.49.8'
import { JWT } from 'npm:google-auth-library@10.1.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

type PushRequest = {
  userIds?: string[]
  title?: string
  body?: string
  orderId?: string | null
  type?: string | null
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  })
}

async function getFcmAccessToken() {
  const clientEmail = Deno.env.get('FCM_CLIENT_EMAIL')
  const privateKey = Deno.env.get('FCM_PRIVATE_KEY')?.replace(/\\n/g, '\n')
  const projectId = Deno.env.get('FCM_PROJECT_ID')

  if (!clientEmail || !privateKey || !projectId) {
    throw new Error(
      'FCM_CLIENT_EMAIL, FCM_PRIVATE_KEY, and FCM_PROJECT_ID must be set before push notifications can be delivered.',
    )
  }

  const jwtClient = new JWT({
    email: clientEmail,
    key: privateKey,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  })
  const tokens = await jwtClient.authorize()
  if (!tokens.access_token) {
    throw new Error('Unable to create an FCM access token.')
  }

  return {
    accessToken: tokens.access_token,
    projectId,
  }
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const authHeader = request.headers.get('Authorization')

    if (!supabaseUrl || !supabaseServiceRoleKey) {
      return jsonResponse(
        { error: 'Missing Supabase function environment configuration.' },
        500,
      )
    }

    if (!authHeader) {
      return jsonResponse({ error: 'Missing Authorization header.' }, 401)
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey)
    const token = authHeader.replace('Bearer ', '')
    const { data: caller, error: callerError } = await supabaseAdmin.auth.getUser(
      token,
    )
    if (callerError || !caller.user) {
      return jsonResponse({ error: 'Unauthorized.' }, 401)
    }

    const payload = (await request.json()) as PushRequest
    const userIds = payload.userIds?.filter(Boolean) ?? []
    if (userIds.length === 0 || !payload.title || !payload.body) {
      return jsonResponse(
        { error: 'userIds, title, and body are required.' },
        400,
      )
    }

    const { data: pushDevices, error: pushDeviceError } = await supabaseAdmin
      .from('push_devices')
      .select('token, user_id')
      .in('user_id', userIds)
      .eq('is_active', true)

    if (pushDeviceError) {
      throw pushDeviceError
    }

    if (!pushDevices || pushDevices.length === 0) {
      return jsonResponse({ sent: 0, skipped: userIds.length })
    }

    const { accessToken, projectId } = await getFcmAccessToken()
    const invalidTokens: string[] = []

    for (const device of pushDevices) {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: device.token,
              notification: {
                title: payload.title,
                body: payload.body,
              },
              data: {
                orderId: payload.orderId ?? '',
                type: payload.type ?? 'order_status',
                title: payload.title,
                body: payload.body,
              },
            },
          }),
        },
      )

      if (response.ok) {
        continue
      }

      const errorText = await response.text()
      if (
        errorText.includes('registration-token-not-registered') ||
        errorText.includes('UNREGISTERED')
      ) {
        invalidTokens.push(device.token)
      }
    }

    if (invalidTokens.length > 0) {
      await supabaseAdmin
        .from('push_devices')
        .update({ is_active: false, updated_at: new Date().toISOString() })
        .in('token', invalidTokens)
    }

    return jsonResponse({
      sent: pushDevices.length - invalidTokens.length,
      invalidated: invalidTokens.length,
    })
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error ? error.message : 'Unexpected push error.',
      },
      500,
    )
  }
})

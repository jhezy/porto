<script setup>
import { ref } from 'vue'
import { useRoute, useRouter, RouterLink } from 'vue-router'
import { isSupabaseConfigured, supabase } from '../lib/supabase'

const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')
const route = useRoute()
const router = useRouter()

async function signIn() {
  error.value = ''
  if (!isSupabaseConfigured || !supabase) {
    error.value = 'Supabase belum dikonfigurasi. Atur VITE_SUPABASE_URL dan VITE_SUPABASE_PUBLISHABLE_KEY pada .env.local.'
    return
  }
  loading.value = true
  const { error: authError } = await supabase.auth.signInWithPassword({
    email: email.value.trim(),
    password: password.value,
  })
  loading.value = false
  if (authError) {
    error.value = 'Login gagal. Periksa email dan password, serta pastikan akun admin sudah dibuat.'
    return
  }
  const redirect = typeof route.query.redirect === 'string' && route.query.redirect.startsWith('/admin')
    ? route.query.redirect
    : '/admin'
  await router.replace(redirect)
}
</script>

<template>
  <div class="min-vh-100 d-flex align-items-center py-5">
    <div class="site-container" style="max-width:480px">
      <RouterLink to="/" class="d-inline-flex align-items-center gap-2 mb-4"><span class="brand-mark">P.</span><strong>PORTFOLIO<span class="text-accent">/</span></strong></RouterLink>
      <div class="panel p-4 p-md-5">
        <p class="eyebrow mb-2">PRIVATE WORKSPACE</p>
        <h1 class="h2 fw-bold mb-2">Admin sign in</h1>
        <p class="text-muted-custom mb-4">Masuk untuk mengelola konten portofolio.</p>
        <div v-if="route.query.setup === 'supabase'" class="alert-app mb-3">Konfigurasikan Supabase terlebih dahulu sebelum login.</div>
        <div v-if="error" class="alert alert-danger py-2 small">{{ error }}</div>
        <form @submit.prevent="signIn" class="d-grid gap-3">
          <div><label for="email" class="form-label small">Email admin</label><input id="email" v-model="email" class="form-control" type="email" autocomplete="username" required placeholder="admin@example.com" /></div>
          <div><label for="password" class="form-label small">Password</label><input id="password" v-model="password" class="form-control" type="password" autocomplete="current-password" required placeholder="••••••••" /></div>
          <button class="btn btn-accent mt-2" type="submit" :disabled="loading">{{ loading ? 'Memproses...' : 'Masuk ke dashboard' }}</button>
        </form>
      </div>
      <p class="text-muted-custom text-center small mt-3">Akses admin dilindungi oleh Supabase Auth dan kebijakan database.</p>
    </div>
  </div>
</template>

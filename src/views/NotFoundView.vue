```vue
<template>
  <main class="not-found">
    <div class="not-found-content">
      <span class="error-code">404</span>

      <h1>Halaman tidak ditemukan</h1>

      <p>
        Sepertinya halaman yang kamu cari tidak tersedia, sudah dipindahkan,
        atau URL yang dimasukkan salah.
      </p>

      <RouterLink
        to="/"
        class="btn-home"
      >
        <i class="bi bi-arrow-left"></i>
        Kembali ke Beranda
      </RouterLink>
    </div>
  </main>
</template>

<script setup>
import { RouterLink } from "vue-router";
</script>

<style scoped>
.not-found {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 2rem;
  background: #0b0e12;
  color: #f5f7fa;
  text-align: center;
}

.not-found-content {
  max-width: 560px;
}

.error-code {
  display: block;
  margin-bottom: 1rem;
  color: #65e6cf;
  font-size: clamp(5rem, 18vw, 9rem);
  font-weight: 800;
  line-height: 1;
  letter-spacing: -0.08em;
}

.not-found h1 {
  margin-bottom: 1rem;
  font-size: clamp(1.5rem, 4vw, 2.25rem);
  font-weight: 700;
}

.not-found p {
  margin-bottom: 2rem;
  color: #9ba5b3;
  line-height: 1.8;
}

.btn-home {
  display: inline-flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.85rem 1.25rem;
  border: 1px solid #65e6cf;
  border-radius: 0.75rem;
  background: #65e6cf;
  color: #0b0e12;
  font-weight: 600;
  text-decoration: none;
  transition: 0.2s ease;
}

.btn-home:hover {
  background: transparent;
  color: #65e6cf;
}
</style>
```

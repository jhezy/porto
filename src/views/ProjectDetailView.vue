<script setup>
import { onMounted, ref, watch } from "vue";
import { RouterLink, useRoute } from "vue-router";
import { usePortfolio } from "../composables/usePortfolio";

const route = useRoute();
const { fetchProjectBySlug } = usePortfolio();

const project = ref(null);
const loading = ref(true);
const error = ref("");

async function loadProject() {
  loading.value = true;
  error.value = "";
  project.value = null;

  try {
    const result = await fetchProjectBySlug(route.params.slug);

    if (!result) {
      error.value = "Proyek yang Anda cari tidak ditemukan.";
      return;
    }

    project.value = result;
  } catch (err) {
    console.error("Gagal memuat detail proyek:", err);
    error.value = "Terjadi kesalahan saat memuat proyek. Silakan coba lagi.";
  } finally {
    loading.value = false;
  }
}

onMounted(loadProject);

watch(() => route.params.slug, loadProject);
</script>

<template>
  <main class="project-detail-page">
    <div class="site-container">
      <!-- Breadcrumb -->
      <nav
        class="project-breadcrumb"
        aria-label="Breadcrumb"
      >
        <RouterLink to="/">Beranda</RouterLink>
        <i class="bi bi-chevron-right"></i>
        <RouterLink to="/#projects">Proyek</RouterLink>
        <i class="bi bi-chevron-right"></i>
        <span>{{ project?.title || "Detail Proyek" }}</span>
      </nav>

      <!-- Loading -->
      <section
        v-if="loading"
        class="project-state-panel"
      >
        <div class="project-spinner"></div>
        <h2>Memuat proyek...</h2>
        <p>Mohon tunggu sebentar.</p>
      </section>

      <!-- Error / project not found -->
      <section
        v-else-if="error || !project"
        class="project-state-panel"
      >
        <div class="project-state-icon">
          <i class="bi bi-folder-x"></i>
        </div>

        <h2>Proyek tidak tersedia</h2>
        <p>{{ error || "Proyek yang Anda cari tidak ditemukan." }}</p>

        <RouterLink
          to="/#projects"
          class="btn-accent"
        >
          <i class="bi bi-arrow-left"></i>
          Kembali ke proyek
        </RouterLink>
      </section>

      <!-- Project detail -->
      <template v-else>
        <!-- Hero: content left, thumbnail right -->
        <section class="project-hero">
          <div class="project-hero-grid">
            <!-- Left: project information -->
            <div class="project-hero-content">
              <RouterLink
                to="/#projects"
                class="project-back"
              >
                <i class="bi bi-arrow-left"></i>
                <span>Kembali ke proyek</span>
              </RouterLink>

              <h1 class="project-title">
                {{ project.title }}
              </h1>

              <p
                v-if="project.summary"
                class="project-summary"
              >
                {{ project.summary }}
              </p>

              <div class="project-actions">
                <a
                  v-if="project.demo_url"
                  :href="project.demo_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="btn-accent"
                >
                  <i class="bi bi-box-arrow-up-right"></i>
                  Live Demo
                </a>

                <a
                  v-if="project.source_url"
                  :href="project.source_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="btn-outline-soft"
                >
                  <i class="bi bi-github"></i>
                  Source Code
                </a>
              </div>

              <div class="project-hero-meta">
                <div class="project-meta-item">
                  <span class="project-meta-dot"></span>
                  <span>Project Details</span>
                </div>

                <span class="project-meta-divider"></span>

                <span class="project-meta-label">Portfolio</span>
              </div>
            </div>

            <!-- Right: project thumbnail -->
            <div
              v-if="project.thumbnail_url"
              class="project-hero-media"
            >
              <div class="project-thumbnail">
                <img
                  :src="project.thumbnail_url"
                  :alt="`Preview ${project.title}`"
                  fetchpriority="high"
                />

                <div class="project-thumbnail-overlay"></div>

                <div class="project-thumbnail-caption">
                  <span class="thumbnail-eyebrow">
                    <span class="thumbnail-live-dot"></span>
                    PROJECT PREVIEW
                  </span>

                  <strong>{{ project.title }}</strong>
                </div>

                <div class="thumbnail-corner-icon">
                  <i class="bi bi-eye"></i>
                </div>
              </div>

              <div class="thumbnail-decoration thumbnail-decoration-one"></div>
              <div class="thumbnail-decoration thumbnail-decoration-two"></div>
            </div>

            <!-- Fallback if no thumbnail -->
            <div
              v-else
              class="project-hero-placeholder"
            >
              <div class="placeholder-icon">
                <i class="bi bi-window-stack"></i>
              </div>
              <span>Project Preview</span>
              <strong>{{ project.title }}</strong>
            </div>
          </div>
        </section>

        <!-- Detail content -->
        <section class="project-content-grid">
          <!-- Description -->
          <article class="project-content-panel project-description-panel">
            <div class="content-panel-heading">
              <div class="content-heading-icon">
                <i class="bi bi-text-paragraph"></i>
              </div>

              <div>
                <span class="content-eyebrow">OVERVIEW</span>
                <h2>Tentang Proyek</h2>
              </div>
            </div>

            <div
              v-if="project.description"
              class="project-description"
            >
              {{ project.description }}
            </div>

            <p
              v-else
              class="project-empty-description"
            >
              Belum ada deskripsi untuk proyek ini.
            </p>
          </article>

          <!-- Project information -->
          <aside class="project-content-panel project-information-panel">
            <div class="content-panel-heading">
              <div class="content-heading-icon">
                <i class="bi bi-info-circle"></i>
              </div>

              <div>
                <span class="content-eyebrow">DETAILS</span>
                <h2>Informasi Proyek</h2>
              </div>
            </div>

            <div class="project-info-list">
              <div class="project-info-item">
                <span class="project-info-label">Nama Proyek</span>
                <strong>{{ project.title }}</strong>
              </div>

              <div class="project-info-item">
                <span class="project-info-label">Kategori</span>
                <strong>{{ project.category || "Tidak dicantumkan" }}</strong>
              </div>

              <div
                v-if="project.tech_stack?.length"
                class="project-info-item project-tech-item"
              >
                <span class="project-info-label">Teknologi</span>

                <div class="project-tech-list">
                  <span
                    v-for="(tech, index) in project.tech_stack"
                    :key="`${tech}-${index}`"
                    class="project-tech-tag"
                  >
                    {{ tech }}
                  </span>
                </div>
              </div>

              <div
                v-else-if="project.technologies"
                class="project-info-item"
              >
                <span class="project-info-label">Teknologi</span>
                <strong>{{ project.technologies }}</strong>
              </div>

              <div
                v-if="project.year"
                class="project-info-item"
              >
                <span class="project-info-label">Tahun</span>
                <strong>{{ project.year }}</strong>
              </div>
            </div>

            <div
              v-if="project.demo_url || project.source_url"
              class="project-info-links"
            >
              <a
                v-if="project.demo_url"
                :href="project.demo_url"
                target="_blank"
                rel="noopener noreferrer"
              >
                <i class="bi bi-box-arrow-up-right"></i>
                Kunjungi website
              </a>

              <a
                v-if="project.source_url"
                :href="project.source_url"
                target="_blank"
                rel="noopener noreferrer"
              >
                <i class="bi bi-github"></i>
                Lihat source code
              </a>
            </div>
          </aside>
        </section>

        <!-- Footer navigation -->
        <footer class="project-detail-footer">
          <div>
            <span class="footer-eyebrow">TERTARIK DENGAN PROYEK INI?</span>
            <h2>Mari bangun sesuatu yang hebat.</h2>
          </div>

          <RouterLink
            to="/#projects"
            class="btn-outline-soft"
          >
            <i class="bi bi-arrow-left"></i>
            Lihat Proyek Lain
          </RouterLink>
        </footer>
      </template>
    </div>
  </main>
</template>

<style scoped>
/* ========================================
   PAGE
======================================== */
.project-detail-page {
  min-height: 100vh;
  padding: 36px 0 80px;
  color: var(--text-primary, #f3f4f6);
}

.project-detail-page .site-container {
  width: min(1180px, calc(100% - 40px));
  margin-inline: auto;
}

/* ========================================
   BREADCRUMB
======================================== */
.project-breadcrumb {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px;
  margin-bottom: 28px;
  color: var(--text-secondary, #9caab3);
  font-size: 0.82rem;
}

.project-breadcrumb a {
  color: inherit;
  text-decoration: none;
  transition: color 0.2s ease;
}

.project-breadcrumb a:hover {
  color: var(--accent, #45d6c5);
}

.project-breadcrumb i {
  color: rgba(156, 170, 179, 0.5);
  font-size: 0.7rem;
}

.project-breadcrumb span {
  max-width: 320px;
  overflow: hidden;
  color: var(--text-primary, #f3f4f6);
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* ========================================
   HERO
======================================== */
.project-hero {
  position: relative;
  isolation: isolate;
  overflow: hidden;
  margin-bottom: 24px;
  padding: 44px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 28px;
  background:
    radial-gradient(
      ellipse at 90% 5%,
      rgba(69, 214, 197, 0.13),
      transparent 38%
    ),
    radial-gradient(
      ellipse at 0% 100%,
      rgba(69, 214, 197, 0.05),
      transparent 45%
    ),
    var(--card-bg, #111a20);
}

.project-hero-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(300px, 0.88fr);
  align-items: center;
  gap: 44px;
}

.project-hero-content {
  position: relative;
  z-index: 2;
  min-width: 0;
}

.project-back {
  display: inline-flex;
  align-items: center;
  gap: 9px;
  margin-bottom: 34px;
  color: var(--text-secondary, #a8b5bd);
  font-size: 0.88rem;
  text-decoration: none;
  transition:
    color 0.2s ease,
    gap 0.2s ease;
}

.project-back:hover {
  gap: 13px;
  color: var(--accent, #45d6c5);
}

.project-category {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 18px;
  padding: 8px 13px;
  border: 1px solid rgba(69, 214, 197, 0.23);
  border-radius: 999px;
  background: rgba(69, 214, 197, 0.07);
  color: var(--accent, #45d6c5);
  font-size: 0.74rem;
  font-weight: 750;
  letter-spacing: 0.09em;
  text-transform: uppercase;
}

.project-title {
  margin: 0 0 20px;
  color: var(--text-primary, #f3f4f6);
  font-size: clamp(2.3rem, 4.2vw, 4rem);
  font-weight: 850;
  letter-spacing: -0.055em;
  line-height: 1.08;
  overflow-wrap: anywhere;
}

.project-summary {
  max-width: 570px;
  margin: 0 0 28px;
  color: var(--text-secondary, #a8b5bd);
  font-size: 1rem;
  line-height: 1.85;
  white-space: pre-line;
}

.project-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px;
}

.project-actions :deep(.btn-accent),
.project-actions :deep(.btn-outline-soft),
.project-detail-footer :deep(.btn-outline-soft),
.project-state-panel :deep(.btn-accent) {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 9px;
  min-height: 46px;
  padding: 12px 18px;
  border-radius: 12px;
  font-size: 0.88rem;
  font-weight: 700;
  text-decoration: none;
  transition:
    transform 0.2s ease,
    background 0.2s ease,
    border-color 0.2s ease;
}

.project-actions :deep(.btn-accent),
.project-state-panel :deep(.btn-accent) {
  border: 1px solid var(--accent, #45d6c5);
  background: var(--accent, #45d6c5);
  color: #071614;
}

.project-actions :deep(.btn-outline-soft),
.project-detail-footer :deep(.btn-outline-soft) {
  border: 1px solid rgba(255, 255, 255, 0.14);
  background: rgba(255, 255, 255, 0.035);
  color: var(--text-primary, #f3f4f6);
}

.project-actions :deep(a:hover),
.project-detail-footer :deep(a:hover),
.project-state-panel :deep(a:hover) {
  transform: translateY(-2px);
}

.project-actions :deep(.btn-outline-soft:hover),
.project-detail-footer :deep(.btn-outline-soft:hover) {
  border-color: rgba(69, 214, 197, 0.45);
  background: rgba(69, 214, 197, 0.07);
}

.project-hero-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 13px;
  margin-top: 34px;
  padding-top: 20px;
  border-top: 1px solid rgba(255, 255, 255, 0.08);
  color: var(--text-secondary, #a8b5bd);
  font-size: 0.76rem;
}

.project-meta-item {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.project-meta-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--accent, #45d6c5);
  box-shadow: 0 0 12px rgba(69, 214, 197, 0.4);
}

.project-meta-divider {
  width: 1px;
  height: 15px;
  background: rgba(255, 255, 255, 0.15);
}

.project-meta-label {
  letter-spacing: 0.04em;
}

/* ========================================
   HERO THUMBNAIL
======================================== */
.project-hero-media {
  position: relative;
  min-width: 0;
  padding: 0 10px 10px 0;
}

.project-thumbnail {
  position: relative;
  z-index: 1;
  overflow: hidden;
  aspect-ratio: 4 / 3;
  border: 1px solid rgba(255, 255, 255, 0.13);
  border-radius: 20px;
  background: #0a1115;
  box-shadow: 0 24px 65px rgba(0, 0, 0, 0.34);
}

.project-thumbnail img {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.6s cubic-bezier(0.2, 0.7, 0.2, 1);
}

.project-thumbnail:hover img {
  transform: scale(1.045);
}

.project-thumbnail-overlay {
  position: absolute;
  inset: 30% 0 0;
  background: linear-gradient(
    180deg,
    transparent 0%,
    rgba(5, 12, 16, 0.22) 35%,
    rgba(5, 12, 16, 0.92) 100%
  );
  pointer-events: none;
}

.project-thumbnail-caption {
  position: absolute;
  right: 22px;
  bottom: 20px;
  left: 22px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.thumbnail-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  color: var(--accent, #45d6c5);
  font-size: 0.66rem;
  font-weight: 800;
  letter-spacing: 0.15em;
}

.thumbnail-live-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--accent, #45d6c5);
  box-shadow: 0 0 10px rgba(69, 214, 197, 0.65);
}

.project-thumbnail-caption strong {
  color: #fff;
  font-size: clamp(1rem, 1.7vw, 1.35rem);
  font-weight: 750;
  line-height: 1.35;
  overflow-wrap: anywhere;
}

.thumbnail-corner-icon {
  position: absolute;
  top: 16px;
  right: 16px;
  display: grid;
  width: 38px;
  height: 38px;
  place-items: center;
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: 12px;
  background: rgba(9, 17, 21, 0.55);
  color: #fff;
  backdrop-filter: blur(10px);
}

.thumbnail-decoration {
  position: absolute;
  border: 1px solid rgba(69, 214, 197, 0.15);
  border-radius: 22px;
  pointer-events: none;
}

.thumbnail-decoration-one {
  inset: 13px 0 0 13px;
}

.thumbnail-decoration-two {
  inset: 26px -1px -1px 26px;
  border-color: rgba(69, 214, 197, 0.07);
}

.project-hero-placeholder {
  display: flex;
  min-height: 280px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  padding: 28px;
  border: 1px dashed rgba(69, 214, 197, 0.24);
  border-radius: 20px;
  background: rgba(69, 214, 197, 0.035);
  color: var(--text-secondary, #a8b5bd);
  text-align: center;
}

.placeholder-icon {
  display: grid;
  width: 62px;
  height: 62px;
  margin-bottom: 6px;
  place-items: center;
  border: 1px solid rgba(69, 214, 197, 0.2);
  border-radius: 18px;
  background: rgba(69, 214, 197, 0.08);
  color: var(--accent, #45d6c5);
  font-size: 1.6rem;
}

.project-hero-placeholder > span {
  font-size: 0.72rem;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.project-hero-placeholder strong {
  color: var(--text-primary, #f3f4f6);
  font-size: 1.1rem;
}

/* ========================================
   CONTENT PANELS
======================================== */
.project-content-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.55fr) minmax(280px, 0.85fr);
  align-items: start;
  gap: 24px;
}

.project-content-panel {
  min-width: 0;
  padding: 30px;
  border: 1px solid rgba(255, 255, 255, 0.075);
  border-radius: 22px;
  background: var(--card-bg, #111a20);
}

.content-panel-heading {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-bottom: 26px;
}

.content-heading-icon {
  display: grid;
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  place-items: center;
  border: 1px solid rgba(69, 214, 197, 0.2);
  border-radius: 13px;
  background: rgba(69, 214, 197, 0.08);
  color: var(--accent, #45d6c5);
  font-size: 1.1rem;
}

.content-eyebrow {
  display: block;
  margin-bottom: 5px;
  color: var(--accent, #45d6c5);
  font-size: 0.65rem;
  font-weight: 800;
  letter-spacing: 0.14em;
}

.content-panel-heading h2 {
  margin: 0;
  color: var(--text-primary, #f3f4f6);
  font-size: 1.18rem;
  font-weight: 750;
}

.project-description {
  color: var(--text-secondary, #a8b5bd);
  font-size: 0.94rem;
  line-height: 1.95;
  white-space: pre-line;
  overflow-wrap: anywhere;
}

.project-empty-description {
  margin: 0;
  color: var(--text-secondary, #a8b5bd);
  font-size: 0.9rem;
  line-height: 1.8;
}

/* ========================================
   PROJECT INFORMATION
======================================== */
.project-info-list {
  display: flex;
  flex-direction: column;
}

.project-info-item {
  display: flex;
  flex-direction: column;
  gap: 9px;
  padding: 17px 0;
  border-bottom: 1px solid rgba(255, 255, 255, 0.075);
}

.project-info-item:first-child {
  padding-top: 0;
}

.project-info-item:last-child {
  border-bottom: 0;
}

.project-info-label {
  color: var(--text-secondary, #8f9da6);
  font-size: 0.76rem;
}

.project-info-item > strong {
  color: var(--text-primary, #f3f4f6);
  font-size: 0.9rem;
  font-weight: 650;
  line-height: 1.6;
  overflow-wrap: anywhere;
}

.project-tech-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.project-tech-tag {
  padding: 6px 10px;
  border: 1px solid rgba(69, 214, 197, 0.15);
  border-radius: 8px;
  background: rgba(69, 214, 197, 0.055);
  color: var(--accent, #45d6c5);
  font-size: 0.75rem;
  overflow-wrap: anywhere;
}

.project-info-links {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-top: 16px;
  padding-top: 20px;
  border-top: 1px solid rgba(255, 255, 255, 0.075);
}

.project-info-links a {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  color: var(--text-secondary, #a8b5bd);
  font-size: 0.84rem;
  text-decoration: none;
  transition: color 0.2s ease;
}

.project-info-links a i {
  color: var(--accent, #45d6c5);
}

.project-info-links a:hover {
  color: var(--accent, #45d6c5);
}

/* ========================================
   FOOTER
======================================== */
.project-detail-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
  margin-top: 24px;
  padding: 30px;
  border: 1px solid rgba(255, 255, 255, 0.075);
  border-radius: 22px;
  background:
    linear-gradient(110deg, rgba(69, 214, 197, 0.07), transparent 65%),
    var(--card-bg, #111a20);
}

.footer-eyebrow {
  display: block;
  margin-bottom: 10px;
  color: var(--accent, #45d6c5);
  font-size: 0.68rem;
  font-weight: 800;
  letter-spacing: 0.12em;
}

.project-detail-footer h2 {
  margin: 0;
  color: var(--text-primary, #f3f4f6);
  font-size: clamp(1.15rem, 2.4vw, 1.65rem);
  font-weight: 750;
  line-height: 1.4;
}

.project-detail-footer :deep(.btn-outline-soft) {
  flex-shrink: 0;
}

/* ========================================
   LOADING / ERROR
======================================== */
.project-state-panel {
  display: flex;
  min-height: 340px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 36px 24px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 24px;
  background: var(--card-bg, #111a20);
  text-align: center;
}

.project-spinner {
  width: 38px;
  height: 38px;
  margin-bottom: 22px;
  border: 3px solid rgba(69, 214, 197, 0.16);
  border-top-color: var(--accent, #45d6c5);
  border-radius: 50%;
  animation: project-spin 0.8s linear infinite;
}

@keyframes project-spin {
  to {
    transform: rotate(360deg);
  }
}

.project-state-icon {
  display: grid;
  width: 64px;
  height: 64px;
  margin-bottom: 20px;
  place-items: center;
  border: 1px solid rgba(69, 214, 197, 0.18);
  border-radius: 20px;
  background: rgba(69, 214, 197, 0.07);
  color: var(--accent, #45d6c5);
  font-size: 1.7rem;
}

.project-state-panel h2 {
  margin: 0 0 10px;
  color: var(--text-primary, #f3f4f6);
  font-size: 1.35rem;
  font-weight: 750;
}

.project-state-panel p {
  max-width: 480px;
  margin: 0 0 24px;
  color: var(--text-secondary, #a8b5bd);
  font-size: 0.9rem;
  line-height: 1.8;
}

.project-state-panel .project-spinner + h2 {
  margin-bottom: 8px;
}

/* ========================================
   RESPONSIVE: TABLET
======================================== */
@media (max-width: 900px) {
  .project-hero {
    padding: 32px;
  }

  .project-hero-grid {
    grid-template-columns: minmax(0, 1fr) minmax(230px, 0.8fr);
    gap: 26px;
  }

  .project-title {
    font-size: clamp(2rem, 4vw, 3rem);
  }

  .project-content-grid {
    grid-template-columns: minmax(0, 1.2fr) minmax(240px, 0.8fr);
    gap: 18px;
  }

  .project-content-panel {
    padding: 24px;
  }
}

/* ========================================
   RESPONSIVE: MOBILE
======================================== */
@media (max-width: 680px) {
  .project-detail-page {
    padding: 24px 0 48px;
  }

  .project-detail-page .site-container {
    width: calc(100% - 28px);
  }

  .project-breadcrumb {
    gap: 8px;
    margin-bottom: 20px;
    font-size: 0.75rem;
  }

  .project-breadcrumb span {
    max-width: 130px;
  }

  .project-hero {
    padding: 20px;
    border-radius: 22px;
  }

  .project-hero-grid {
    grid-template-columns: minmax(0, 1fr);
    gap: 28px;
  }

  /* Thumbnail tampil di atas konten pada layar kecil */
  .project-hero-media {
    grid-row: 1;
    padding: 0 6px 6px 0;
  }

  .project-thumbnail {
    aspect-ratio: 16 / 10;
    border-radius: 16px;
  }

  .project-thumbnail-caption {
    right: 16px;
    bottom: 15px;
    left: 16px;
  }

  .thumbnail-corner-icon {
    top: 12px;
    right: 12px;
    width: 34px;
    height: 34px;
  }

  .project-hero-content {
    grid-row: 2;
  }

  .project-back {
    margin-bottom: 24px;
  }

  .project-category {
    margin-bottom: 14px;
  }

  .project-title {
    margin-bottom: 16px;
    font-size: clamp(2rem, 9vw, 2.8rem);
  }

  .project-summary {
    margin-bottom: 24px;
    font-size: 0.92rem;
    line-height: 1.8;
  }

  .project-hero-meta {
    margin-top: 26px;
  }

  .project-content-grid {
    grid-template-columns: minmax(0, 1fr);
    gap: 16px;
  }

  .project-content-panel {
    padding: 24px 20px;
    border-radius: 18px;
  }

  .content-panel-heading {
    margin-bottom: 22px;
  }

  .project-detail-footer {
    align-items: flex-start;
    flex-direction: column;
    gap: 20px;
    padding: 24px 20px;
    border-radius: 18px;
  }
}

/* ========================================
   RESPONSIVE: SMALL MOBILE
======================================== */
@media (max-width: 380px) {
  .project-detail-page .site-container {
    width: calc(100% - 22px);
  }

  .project-hero {
    padding: 16px;
  }

  .project-actions {
    align-items: stretch;
    flex-direction: column;
  }

  .project-actions :deep(a) {
    width: 100%;
  }

  .project-hero-meta {
    gap: 9px;
    font-size: 0.7rem;
  }

  .project-content-panel {
    padding: 20px 16px;
  }
}

@media (prefers-reduced-motion: reduce) {
  .project-spinner {
    animation-duration: 1.8s;
  }

  .project-thumbnail img,
  .project-back,
  .project-actions :deep(a),
  .project-detail-footer :deep(a) {
    transition: none;
  }
}
</style>

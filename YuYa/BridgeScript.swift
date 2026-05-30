//
//  BridgeScript.swift
//  YuYa
//
//  Created by Maksim Cherkasov on 30.05.2026.
//

import Foundation

enum BridgeScript {
    static func source(for service: MusicService) -> String {
        """
        (() => {
          if (window.__yuyaBridgeInstalled) {
            return;
          }
          window.__yuyaBridgeInstalled = true;

          const serviceID = \(javaScriptString(service.id));
          const serviceName = \(javaScriptString(service.displayName));
          const bridgeName = "yuyaBridge";
          const state = {
            handlers: {},
            lastMediaElement: null,
            lastPayload: "",
            lastPublishAt: 0
          };

          function post(payload) {
            try {
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[bridgeName]) {
                window.webkit.messageHandlers[bridgeName].postMessage(payload);
              }
            } catch (_) {}
          }

          function finiteNumber(value) {
            return Number.isFinite(value) ? value : null;
          }

          function cleanString(value) {
            if (typeof value !== "string") {
              return null;
            }
            const cleaned = value.trim();
            return cleaned.length > 0 ? cleaned : null;
          }

          function currentMetadata() {
            const mediaSession = navigator.mediaSession;
            const metadata = mediaSession && mediaSession.metadata ? mediaSession.metadata : null;
            const artwork = metadata && Array.isArray(metadata.artwork) && metadata.artwork.length > 0
              ? metadata.artwork[metadata.artwork.length - 1].src
              : null;

            return {
              title: cleanString(metadata && metadata.title),
              artist: cleanString(metadata && metadata.artist),
              album: cleanString(metadata && metadata.album),
              artworkURL: cleanString(artwork)
            };
          }

          function rememberMediaElement(element) {
            if (element && typeof HTMLMediaElement !== "undefined" && element instanceof HTMLMediaElement) {
              state.lastMediaElement = element;
            }
          }

          function collectMediaElements(root, result, seenRoots) {
            if (!root || seenRoots.has(root)) {
              return;
            }
            seenRoots.add(root);

            try {
              if (root.querySelectorAll) {
                root.querySelectorAll("audio, video").forEach(element => result.push(element));
                root.querySelectorAll("*").forEach(element => {
                  if (element.shadowRoot) {
                    collectMediaElements(element.shadowRoot, result, seenRoots);
                  }
                  if (element.tagName === "IFRAME" || element.tagName === "FRAME") {
                    try {
                      collectMediaElements(element.contentDocument, result, seenRoots);
                    } catch (_) {}
                  }
                });
              }
            } catch (_) {}
          }

          function mediaElements() {
            const elements = [];
            collectMediaElements(document, elements, new Set());
            if (state.lastMediaElement && !elements.includes(state.lastMediaElement)) {
              elements.unshift(state.lastMediaElement);
            }
            return elements;
          }

          function activeMediaElement() {
            const elements = mediaElements();
            if (elements.length === 0) {
              return null;
            }

            return elements
              .slice()
              .sort((a, b) => {
                const aScore = (a.paused ? 0 : 8) + (a.currentTime > 0 ? 4 : 0) + (a.duration ? 2 : 0) + (a.currentSrc ? 1 : 0);
                const bScore = (b.paused ? 0 : 8) + (b.currentTime > 0 ? 4 : 0) + (b.duration ? 2 : 0) + (b.currentSrc ? 1 : 0);
                return bScore - aScore;
              })[0];
          }

          function capabilities() {
            return {
              canPlay: true,
              canPause: true,
              canTogglePlayPause: true,
              canNextTrack: Boolean(state.handlers.nexttrack) || Boolean(findCommandButton("next")),
              canPreviousTrack: Boolean(state.handlers.previoustrack) || Boolean(findCommandButton("previous"))
            };
          }

          function snapshot() {
            const element = activeMediaElement();
            const metadata = currentMetadata();
            const mediaSession = navigator.mediaSession;
            const sessionState = mediaSession && typeof mediaSession.playbackState === "string"
              ? mediaSession.playbackState
              : "none";
            const isPlaying = sessionState === "playing" || Boolean(element && !element.paused);

            return {
              serviceID,
              serviceName,
              title: metadata.title || cleanString(document.title),
              artist: metadata.artist,
              album: metadata.album,
              artworkURL: metadata.artworkURL,
              duration: element ? finiteNumber(element.duration) : null,
              position: element ? finiteNumber(element.currentTime) : null,
              isPlaying,
              capabilities: capabilities()
            };
          }

          function publish(force = false) {
            const payload = {
              type: "playback",
              serviceID,
              snapshot: snapshot()
            };
            const serialized = JSON.stringify(payload);
            const now = Date.now();
            if (force || serialized !== state.lastPayload || now - state.lastPublishAt > 5000) {
              state.lastPayload = serialized;
              state.lastPublishAt = now;
              post(payload);
            }
          }

          function wrapMediaSession() {
            try {
              const mediaSession = navigator.mediaSession;
              if (!mediaSession || mediaSession.__yuyaWrappedSetActionHandler || !mediaSession.setActionHandler) {
                return;
              }

              const originalSetActionHandler = mediaSession.setActionHandler.bind(mediaSession);
              mediaSession.setActionHandler = function(action, handler) {
                if (typeof handler === "function") {
                  state.handlers[action] = handler;
                } else {
                  delete state.handlers[action];
                }
                publish(true);
                return originalSetActionHandler(action, handler);
              };
              mediaSession.__yuyaWrappedSetActionHandler = true;
            } catch (_) {}
          }

          function wrapHTMLMediaElement() {
            try {
              if (typeof HTMLMediaElement === "undefined") {
                return;
              }

              const prototype = HTMLMediaElement.prototype;
              if (prototype.__yuyaWrappedPlaybackMethods) {
                return;
              }

              const originalPlay = prototype.play;
              const originalPause = prototype.pause;

              if (typeof originalPlay === "function") {
                prototype.play = function(...args) {
                  rememberMediaElement(this);
                  const result = originalPlay.apply(this, args);
                  Promise.resolve(result)
                    .then(() => publish(true))
                    .catch(() => publish(true));
                  setTimeout(() => publish(true), 0);
                  return result;
                };
              }

              if (typeof originalPause === "function") {
                prototype.pause = function(...args) {
                  rememberMediaElement(this);
                  const result = originalPause.apply(this, args);
                  setTimeout(() => publish(true), 0);
                  return result;
                };
              }

              prototype.__yuyaWrappedPlaybackMethods = true;
            } catch (_) {}
          }

          function commandSelectors(kind) {
            if (kind === "next") {
              return [
                "[aria-label='Next']",
                "[aria-label='Следующий трек']",
                "[aria-label='Следующий']",
                "[title='Next']",
                "[title='Следующий трек']",
                ".next-button button",
                "ytmusic-player-bar .next-button",
                ".PlayerBar-Forward",
                ".player-controls__btn_next"
              ];
            }

            if (kind === "previous") {
              return [
                "[aria-label='Previous']",
                "[aria-label='Previous track']",
                "[aria-label='Предыдущий трек']",
                "[aria-label='Предыдущий']",
                "[title='Previous']",
                "[title='Предыдущий трек']",
                ".previous-button button",
                "ytmusic-player-bar .previous-button",
                ".PlayerBar-Backward",
                ".player-controls__btn_prev"
              ];
            }

            if (kind === "pause") {
              return [
                "[aria-label='Pause']",
                "[aria-label='Пауза']",
                "[title='Pause']",
                "[title='Пауза']",
                "ytmusic-player-bar #play-pause-button[title='Pause']",
                "ytmusic-player-bar .play-pause-button[title='Pause']",
                ".PlayerBar-PlayButton[aria-label='Пауза']",
                ".player-controls__btn_pause"
              ];
            }

            if (kind === "play") {
              return [
                "[aria-label='Play']",
                "[aria-label='Воспроизведение']",
                "[title='Play']",
                "[title='Воспроизведение']",
                "ytmusic-player-bar #play-pause-button[title='Play']",
                "ytmusic-player-bar .play-pause-button[title='Play']",
                ".PlayerBar-PlayButton[aria-label='Воспроизведение']",
                ".player-controls__btn_play"
              ];
            }

            if (kind === "playPause") {
              return [
                "ytmusic-player-bar #play-pause-button",
                "ytmusic-player-bar .play-pause-button",
                ".PlayerBar-PlayButton",
                ".player-controls__btn_play",
                ".player-controls__btn_pause"
              ];
            }

            return [
              "[aria-label='Previous']",
              "[aria-label='Previous track']",
              "[aria-label='Предыдущий трек']",
              "[aria-label='Предыдущий']",
              "[title='Previous']",
              "[title='Предыдущий трек']",
              ".previous-button button",
              "ytmusic-player-bar .previous-button",
              ".PlayerBar-Backward",
              ".player-controls__btn_prev"
            ];
          }

          function findCommandButton(kind) {
            return commandButtonCandidates(kind)[0] || null;
          }

          function commandButtonCandidates(kind) {
            const seen = new Set();
            const candidates = [];
            const selectors = commandSelectors(kind);
            for (const selector of selectors) {
              document.querySelectorAll(selector).forEach(button => {
                if (isUsableButton(button) && !seen.has(button)) {
                  seen.add(button);
                  candidates.push(button);
                }
              });
            }

            document.querySelectorAll("button, [role='button']").forEach(button => {
              if (!isUsableButton(button) || seen.has(button)) {
                return;
              }

              const descriptor = buttonDescriptor(button).toLowerCase();
              if (matchesCommandDescriptor(kind, descriptor)) {
                seen.add(button);
                candidates.push(button);
              }
            });

            return candidates;
          }

          function isUsableButton(button) {
            return Boolean(
              button &&
              !button.disabled &&
              button.getAttribute("aria-disabled") !== "true" &&
              button.getClientRects().length > 0
            );
          }

          function buttonDescriptor(button) {
            return [
              button.getAttribute("aria-label"),
              button.getAttribute("title"),
              button.textContent,
              button.className
            ].map(value => String(value || "")).join(" ");
          }

          function matchesCommandDescriptor(kind, descriptor) {
            if (kind === "pause") {
              return descriptor.includes("pause") || descriptor.includes("пауза");
            }
            if (kind === "play") {
              return descriptor.includes("play") || descriptor.includes("воспроизведение");
            }
            if (kind === "playPause") {
              return matchesCommandDescriptor("pause", descriptor) || matchesCommandDescriptor("play", descriptor);
            }
            if (kind === "next") {
              return descriptor.includes("next") || descriptor.includes("следующ");
            }
            if (kind === "previous") {
              return descriptor.includes("previous") || descriptor.includes("предыдущ");
            }
            return false;
          }

          function pauseMediaElements() {
            let pausedAny = false;
            for (const mediaElement of mediaElements()) {
              if (mediaElement && mediaElement.pause && !mediaElement.paused) {
                try {
                  mediaElement.pause();
                  pausedAny = true;
                } catch (_) {}
              }
            }
            return pausedAny;
          }

          function forcePausePlayback() {
            const pausedAny = pauseMediaElements();
            if (pausedAny && navigator.mediaSession) {
              try {
                navigator.mediaSession.playbackState = "paused";
              } catch (_) {}
            }
            publishAfterCommand();
            return pausedAny;
          }

          function publishAfterCommand() {
            publish(true);
            setTimeout(() => publish(true), 250);
            setTimeout(() => publish(true), 900);
          }

          async function runCommand(command) {
            const element = activeMediaElement();
            try {
              if (command === "play") {
                if (state.handlers.play) {
                  await state.handlers.play();
                  publishAfterCommand();
                  return true;
                }
                if (element && element.play) {
                  await element.play();
                  publishAfterCommand();
                  return true;
                }
                const button = findCommandButton("play") || findCommandButton("playPause");
                if (button) {
                  button.click();
                  publishAfterCommand();
                  return true;
                }
              }

              if (command === "pause") {
                const before = snapshot();
                if (state.handlers.pause) {
                  await state.handlers.pause();
                  forcePausePlayback();
                  return true;
                }
                if (forcePausePlayback()) {
                  return true;
                }
                if (before.isPlaying) {
                  const button = findCommandButton("pause") || findCommandButton("playPause");
                  if (button) {
                    button.click();
                    publishAfterCommand();
                    return true;
                  }
                }
              }

              if (command === "togglePlayPause") {
                const before = snapshot();
                if (before.isPlaying && state.handlers.pause) {
                  await state.handlers.pause();
                  forcePausePlayback();
                  return true;
                }
                if (!before.isPlaying && state.handlers.play) {
                  await state.handlers.play();
                  publishAfterCommand();
                  return true;
                }
                if (element && element.paused && element.play) {
                  await element.play();
                  publishAfterCommand();
                  return true;
                }
                if (element && element.pause) {
                  element.pause();
                  publishAfterCommand();
                  return true;
                }
                const button = findCommandButton("playPause");
                if (button) {
                  button.click();
                  publishAfterCommand();
                  return true;
                }
              }

              if (command === "nextTrack") {
                if (state.handlers.nexttrack) {
                  await state.handlers.nexttrack();
                  publishAfterCommand();
                  return true;
                }
                const button = findCommandButton("next");
                if (button) {
                  button.click();
                  publishAfterCommand();
                  return true;
                }
              }

              if (command === "previousTrack") {
                if (state.handlers.previoustrack) {
                  await state.handlers.previoustrack();
                  publishAfterCommand();
                  return true;
                }
                const button = findCommandButton("previous");
                if (button) {
                  button.click();
                  publishAfterCommand();
                  return true;
                }
              }
            } catch (error) {
              post({
                type: "commandResult",
                serviceID,
                command,
                succeeded: false,
                message: String(error && error.message ? error.message : error)
              });
              return false;
            }

            post({
              type: "commandResult",
              serviceID,
              command,
              succeeded: false,
              message: "No controllable media element or command handler was found."
            });
            return false;
          }

          window.__yuyaBridge = {
            command: async function(command) {
              const succeeded = await runCommand(command);
              post({
                type: "commandResult",
                serviceID,
                command,
                succeeded
              });
            },
            forcePause: function() {
              return forcePausePlayback();
            },
            publish
          };

          wrapHTMLMediaElement();
          wrapMediaSession();
          publish(true);

          ["play", "pause", "playing", "timeupdate", "durationchange", "loadedmetadata", "emptied", "ended"].forEach(eventName => {
            document.addEventListener(eventName, event => {
              rememberMediaElement(event.target);
              publish(false);
            }, true);
          });

          document.addEventListener("visibilitychange", () => publish(true), true);
          window.addEventListener("pageshow", () => publish(true), true);
          window.addEventListener("focus", () => publish(true), true);
          setInterval(() => {
            wrapHTMLMediaElement();
            wrapMediaSession();
            publish(false);
          }, 1000);
        })();
        """
    }

    private static func javaScriptString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let encoded = String(data: data, encoding: .utf8),
              encoded.count >= 2
        else {
            return "\"\""
        }

        return String(encoded.dropFirst().dropLast())
    }
}
